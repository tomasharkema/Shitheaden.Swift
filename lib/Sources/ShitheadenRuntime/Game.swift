//
//  Game.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Foundation
import Logging
import ShitheadenShared

public final actor Game {
  private let logger = Logger(label: "runtime.Game")

  private(set) var deck = Deck(cards: [])
  var players = [Player]()
  private(set) var table = Table()
  private(set) var burnt = [Card]()
  var turns = [(String, Turn)]()
  let rules = Rules.all
  var slowMode = false
  var playersOnTurn = Set<UUID>()
  var playerAndError = [UUID: PlayerError]()

  public init(
    players: [Player],
    slowMode: Bool
  ) {
    self.players = players
    self.slowMode = slowMode
  }

  var lastCard: Card? {
    return table.lastCard
  }

  var notDonePlayers: [Player] {
    return Array(players.filter { !$0.done })
  }

  public var done: Bool {
    notDonePlayers.count == 1
  }

  private func getEndState(player: Player) -> EndState? {
    let sorted = players.sorted { $0.turns.count < $1.turns.count }

    guard let order = sorted.firstIndex(of: player) else {
      return nil
    }

    if order == 0 {
      return .winner
    } else {
      return .place(order + 1)
    }
  }

  private func getPlayerSnapshot(_ obscure: Bool, player: Player,
                                 includeEndState: Bool) -> TurnRequest
  {
    if obscure {
      return TurnRequest(
        id: player.id,
        name: player.name,
        handCards: .init(obscured: player.handCards),
        openTableCards: .init(open: player.openTableCards),
        lastTableCard: table.lastCard,
        closedCards: .init(obscured: player.closedTableCards),
        phase: player.phase,
        tableCards: .init(open: table, limit: 5),
        deckCards: .init(obscured: deck.cards),
        algoName: player.ai.algoName,
        done: player.done,
        position: player.position,
        isObscured: obscure,
        playerError: nil,
        endState: includeEndState ? getEndState(player: player) : nil
      )
    } else {
      return TurnRequest(
        id: player.id,
        name: player.name,
        handCards: .init(open: player.handCards),
        openTableCards: .init(open: player.openTableCards),
        lastTableCard: table.lastCard,
        closedCards: .init(obscured: player.closedTableCards),
        phase: player.phase,
        tableCards: .init(open: table, limit: 5),
        deckCards: .init(obscured: deck.cards),
        algoName: player.ai.algoName,
        done: player.done,
        position: player.position,
        isObscured: obscure,
        playerError: playerAndError[player.id],
        endState: includeEndState ? getEndState(player: player) : nil
      )
    }
  }

  public func getSnapshot(for uuid: UUID?, includeEndState: Bool) -> GameSnapshot {
    return GameSnapshot(
      deckCards: deck.cards.map { .hidden(id: $0.id) },
      players: players.map {
        getPlayerSnapshot($0.id != uuid, player: $0, includeEndState: includeEndState)
      }.orderPosition(for: uuid),
      tableCards: .init(open: table, limit: 5),
      burntCards: burnt.map { .hidden(id: $0.id) },
      playersOnTurn: playersOnTurn,
      requestFor: uuid
    )
  }

  func shuffle() {
    deck = .new
  }

  func deel() {
    for (index, _) in players.enumerated() {
      players[index].handCards = [
        deck.draw()!,
        deck.draw()!,
        deck.draw()!,
        deck.draw()!,
        deck.draw()!,
        deck.draw()!,
      ]

      players[index].sortCards()
      players[index].closedTableCards = [deck.draw()!, deck.draw()!, deck.draw()!]
    }
  }

  func commitBeginTurn(
    playerIndex: Int,
    player oldP: Player,
    numberCalled: Int,
    previousError: PlayerError?
  ) async throws -> Player {
    var player = oldP

    try Task.checkCancellation()

    player.sortCards()

    let req = TurnRequest(
      id: player.id, name: player.name,
      handCards: .init(open: player.handCards),
      openTableCards: .init(open: player.openTableCards),
      lastTableCard: table.lastCard,
      closedCards: .init(obscured: player.closedTableCards),
      phase: player.phase,
      tableCards: .init(obscured: table),
      deckCards: .init(obscured: deck.cards),
      algoName: player.ai.algoName,
      done: player.done,
      position: player.position,
      isObscured: false,
      playerError: previousError,
      endState: nil
    )

    try await sendRender(error: previousError)

    do {
      let (card1, card2, card3) = try await player.ai
        .beginMove(request: req)

      // verify turn
      if [card1, card2, card3].contains(where: {
        !player.handCards.contains($0)
      }) {
        throw PlayerError.cardNotInHand
      }

      playerAndError[player.id] = nil

      player.handCards.remove(at: player.handCards.firstIndex(of: card1)!)
      player.handCards.remove(at: player.handCards.firstIndex(of: card2)!)
      player.handCards.remove(at: player.handCards.firstIndex(of: card3)!)

      player.openTableCards.append(card1)
      player.openTableCards.append(card2)
      player.openTableCards.append(card3)

      return player
    } catch {
      try await sendRender(error: (error as? PlayerError) ?? previousError)

      return try await commitBeginTurn(
        playerIndex: playerIndex,
        player: oldP,
        numberCalled: numberCalled,
        previousError: (error as? PlayerError) ?? previousError
      )
    }
  }

  private func sendRender(error _: PlayerError?, includeEndState: Bool = false) async throws {
    for player in players {
      try await player.ai
        .render(snapshot: getSnapshot(for: player.id, includeEndState: includeEndState))
    }
  }

  private func playDelayIfNeeded(multiplier: Double = 1.0) async {
    if slowMode {
      let userPlayer = players.first { $0.ai.algoName.isUser }
      if !(userPlayer?.done ?? true) {
        await delay(for: .now() + (0.5 * multiplier))
      }
    }
  }

  func commitTurn(
    playerIndex: Int,
    player oldP: Player,
    numberCalled: Int, previousError: PlayerError?
  ) async throws -> Player {
    var player = oldP

    try Task.checkCancellation()

    guard !player.done, !done, numberCalled < 100 else {
      return player
    }

    player.sortCards()

    let req = TurnRequest(
      id: player.id, name: player.name,
      handCards: .init(open: player.handCards),
      openTableCards: .init(open: player.openTableCards),
      lastTableCard: table.lastCard,
      closedCards: .init(obscured: player.closedTableCards),
      phase: player.phase,
      tableCards: .init(obscured: table),
      deckCards: .init(obscured: deck.cards),
      algoName: player.ai.algoName,
      done: player.done,
      position: player.position,
      isObscured: false,
      playerError: previousError, endState: nil
    )

    await playDelayIfNeeded()

    try await sendRender(error: previousError)

    do {
      let turn = try await player.ai.move(request: req)

      do {
        try turn.verify()
        try await sendRender(error: previousError)
      } catch {
        if !type(of: player.ai).algoName.contains("UserInputAI") {
          logger
            .error(
              "TURN IS NOT POSSIBLE \(numberCalled), \(player.ai.algoName), \(String(describing: player.phase)), \(String(describing: turn)), \(String(describing: req._possibleTurns()))"
            )
          assertionFailure("This is not possible \(type(of: player.ai))")
        }
        try await sendRender(error: error as? PlayerError ?? PlayerError
          .turnNotPossible(turn: turn))

        return try await commitTurn(
          playerIndex: playerIndex,
          player: player,
          numberCalled: numberCalled + 1,
          previousError: (error as? PlayerError) ?? PlayerError.turnNotPossible(turn: turn)
        )
      }

      guard req._possibleTurns().contains(turn) else {
        if !type(of: player.ai).algoName.contains("UserInputAI") {
          logger
            .error(
              "TURN IS NOT POSSIBLE \(numberCalled), \(player.ai.algoName), \(String(describing: player.phase)), \(String(describing: turn)), \(String(describing: req._possibleTurns()))"
            )
          assertionFailure("This is not possible \(type(of: player.ai))")
        }
        return try await commitTurn(
          playerIndex: playerIndex,
          player: player,
          numberCalled: numberCalled + 1,
          previousError: PlayerError.turnNotPossible(turn: turn)
        )
      }

      player.turns.append(turn)
      playerAndError[player.id] = nil
      switch turn {
      case let .closedCardIndex(index):
        if player.phase == .tableClosed {
          let previousTable = table
          let card = player.closedTableCards[index - 1]

          player.closedTableCards.remove(at: player.closedTableCards.firstIndex(of: card)!)

          table += [card]

          if let lastTable = previousTable.filter({ $0.number != .three }).last,
             let lastApplied = table.filter({ $0.number != .three }).last,
             !lastTable.number.afters.contains(lastApplied.number)
          {
            try await sendRender(error: previousError)
            await playDelayIfNeeded(multiplier: 2)

            player.handCards.append(contentsOf: table)
            table = []
            updatePlayer(player: player)
            try await sendRender(error: previousError)
            if rules.contains(.againAfterPass) {
              return try await commitTurn(
                playerIndex: playerIndex,
                player: player,
                numberCalled: numberCalled + 1,
                previousError: previousError ??
                  PlayerError.closedCardFailed(lastApplied)
              )
            }
          }
        } else {
//        throw PlayerError(text: "Can not throw closedCardIndex")
          fatalError("Can not throw closedCardIndex")
        }
      case let .play(possibleBeurt):
        logger
          .info(
            "play possibleBeurt \(String(describing: possibleBeurt)) handCards \(String(describing: player.handCards))"
          )

        table.append(contentsOf: possibleBeurt)

        switch player.phase {
        case .hand:
          assert(!possibleBeurt.contains { !player.handCards.contains($0) }, "WTF")

          for p in possibleBeurt {
            player.handCards.remove(at: player.handCards.firstIndex(of: p)!)
          }

          for _ in 0 ..< 3 {
            if player.handCards.count < 3, let newCard = deck.draw() {
              player.handCards.append(newCard)
            } else {
              continue
            }
          }

        case .tableOpen:
          assert(!possibleBeurt.contains { !player.openTableCards.contains($0) }, "WTF")
          for p in possibleBeurt {
            player.openTableCards.remove(at: player.openTableCards.firstIndex(of: p)!)
          }

        case .tableClosed:
          fatalError("Cannot play in this phase")
        }

      case .pass:
        player.handCards.append(contentsOf: table)
        table = []
      }

      turns += [(player.name, turn)]

      try await sendRender(error: previousError)

      if turn == .pass, rules.contains(.againAfterPass), !player.done, !done {
        try await sendRender(error: previousError)
        updatePlayer(player: player)
        return try await commitTurn(
          playerIndex: playerIndex,
          player: player,
          numberCalled: 0, previousError: nil
        )
      }

      if lastCard?.number == .ten {
        try await sendRender(error: previousError)
        await playDelayIfNeeded(multiplier: 2)

        burnt += table
        table = []

        try await sendRender(error: previousError)
        updatePlayer(player: player)

        if rules.contains(.againAfterGoodBehavior), !player.done, !done {
          return try await commitTurn(
            playerIndex: playerIndex,
            player: player,
            numberCalled: 0, previousError: nil
          )
        }
      } else if table.suffix(4).reduce((0, nil) as (Int, Number?), { prev, curr in
        if let prefNumber = prev.1 {
          if prefNumber == curr.number {
            return (prev.0 + 1, prefNumber)
          } else {
            return (prev.0, prefNumber)
          }
        } else {
          return (1, curr.number)
        }
      }).0 == 4 {
        try await sendRender(error: previousError)
        await playDelayIfNeeded(multiplier: 2)

        burnt.append(contentsOf: table)
        table = []
        try await sendRender(error: previousError)
        updatePlayer(player: player)
        if rules.contains(.againAfterGoodBehavior), !player.done, !done {
          return try await commitTurn(
            playerIndex: playerIndex,
            player: player,
            numberCalled: 0, previousError: nil
          )
        }
      }
      return player

    } catch {
      try Task.checkCancellation()
      try await sendRender(error: error as? PlayerError ?? previousError)

      return try await commitTurn(
        playerIndex: playerIndex,
        player: player,
        numberCalled: numberCalled + 1,
        previousError: error as? PlayerError
      )
    }
  }

  private func updatePlayer(player: Player) {
    guard let index = players.firstIndex(where: { player.id == $0.id }) else {
      assertionFailure("User not found!")
      return
    }

    players[index] = player
  }

  private func startPlayerOnSet(player: Player) {
    playersOnTurn.insert(player.id)
  }

  private func removePlayerOnSet(player: Player) {
    playersOnTurn.remove(player.id)
  }

  func beginRound() async throws {
    try Task.checkCancellation()
//    return await withTaskGroup(of: Void.self) { g in
    for (index, player) in await players.enumerated() {
//        g.async {
      do {
        await startPlayerOnSet(player: player)

        let newPlayer = try await commitBeginTurn(
          playerIndex: index,
          player: player,
          numberCalled: 0,
          previousError: nil
        )
        await removePlayerOnSet(player: player)
        await updatePlayer(player: newPlayer)
        try! await checkIntegrity()
        try! await sendRender(error: nil)
      } catch {
        assertionFailure("\(error)")
      }
//        }
//      }
    }
  }

  func turn(n: Int = 0) async throws {
    try Task.checkCancellation()

    for (index, player) in players.enumerated() {
      try Task.checkCancellation()
      if !player.done {
        playersOnTurn.insert(player.id)
        players[index] = try await commitTurn(
          playerIndex: index, player: player,
          numberCalled: 0, previousError: nil
        )
        try! checkIntegrity()
        playersOnTurn.remove(player.id)
        try await sendRender(error: nil)
      }
    }
    if n > 1000 {
      logger
        .error(
          "ERROR! GAME REACHED MAXIMUM OF 1000 TURNS! \(String(describing: getSnapshot(for: nil, includeEndState: true)))"
        )
      return
    }

    if !done {
      return try await turn(n: n + 1)
    }
  }

  func pickDonePlayers() -> [Player] {
    return players.filter { el -> Bool in
      el.done
    }
  }

  func shouldDoAnotherRound() -> Bool {
    return pickDonePlayers().count != (players.count - 1) && pickDonePlayers().count != players
      .count
  }

  func resetBeurten() {
    for (index, _) in players.enumerated() {
      players[index].turns = []
    }
  }

  public func startGame() async throws -> GameSnapshot {
    try Task.checkCancellation()

    resetBeurten()

    try Task.checkCancellation()
    try await sendRender(error: nil)

    shuffle()
    deel()
    try Task.checkCancellation()
    try await sendRender(error: nil)
    try Task.checkCancellation()
    try await beginRound()

    try Task.checkCancellation()
    players = players.sortPlayerLowestCard()

    try Task.checkCancellation()
    try await turn()

    try Task.checkCancellation()
    try await sendRender(error: nil, includeEndState: true)
    return getSnapshot(for: nil, includeEndState: true)
  }

  func checkIntegrity() throws {
    #if DEBUG
      var pastCards = [(Card, String)]()

      for player in players {
        for handCard in player.handCards {
          if let card = pastCards.first(where: { $0.0 == handCard }) {
            throw PlayerError.integrityDoubleCardEncountered(card.0)
          }
          pastCards.append((handCard, "\(player.name):hand"))
        }
        for openTableCard in player.openTableCards {
          if let card = pastCards.first(where: { $0.0 == openTableCard }) {
            throw PlayerError.integrityDoubleCardEncountered(card.0)
          }
          pastCards.append((openTableCard, "\(player.name):openTableCard"))
        }
        for closedTableCard in player.closedTableCards {
          if let card = pastCards.first(where: { $0.0 == closedTableCard }) {
            throw PlayerError.integrityDoubleCardEncountered(card.0)
          }
          pastCards.append((closedTableCard, "\(player.name):closedTableCard"))
        }
      }

      for c in table {
        if let found = pastCards.first(where: { $0.0 == c }) {
          throw PlayerError.integrityDoubleCardEncountered(found.0)
        }
        pastCards.append((c, "table"))
      }

      for c in deck.cards {
        if let card = pastCards.first(where: { $0.0 == c }) {
          throw PlayerError.integrityDoubleCardEncountered(card.0)
        }
        pastCards.append((c, "deck"))
      }

      for c in burnt {
        if let card = pastCards.first(where: { $0.0 == c }) {
          throw PlayerError.integrityDoubleCardEncountered(card.0)
        }
        pastCards.append((c, "burnt"))
      }

      if pastCards.count != 52 {
        throw PlayerError.integrityCardCount
      }

    #endif
  }

  deinit {
    logger.debug("DEINIT")
  }
}

public extension String {
  nonisolated var isUser: Bool {
    return contains("UserInputAI")
  }
}

extension Array where Element == TurnRequest {
  func orderPosition(for id: UUID?) -> [TurnRequest] {
    guard let id = id, let offsetForZuid = Position.allCases.firstIndex(of: .zuid),
          let offsetForPlayer = firstIndex(where: { $0.id == id })
    else {
      return self
    }

    return enumerated()
      .map { index, element in
        var newElement = element
        newElement.position = Position.allCases.shifted(by: offsetForPlayer - offsetForZuid)[index]
        return newElement
      }
  }
}
