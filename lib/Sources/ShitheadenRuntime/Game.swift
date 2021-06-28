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

// swiftlint:disable:next type_body_length
public final actor Game {
  private let logger = Logger(label: "runtime.Game")

  let beginDate = Date()
  var endDate: Date?

  private(set) var deck = Deck(cards: [])
  var players = [Player]()
  private(set) var table = Table()
  private(set) var burnt = [Card]()

  #if DEBUG
    public func privateSetBurnt(_ cards: [Card]) {
      burnt = cards
    }
  #endif

  var turns = [(String, Turn)]()
  let rules = Rules.all
  var slowMode = false
  var playersOnTurn = Set<UUID>()
  var playerAndError = [UUID: PlayerError]()

  public init(
    players: [Player],
    slowMode: Bool
  ) {
    #if DEBUG
      var ids = [UUID]()
      for player in players {
        if ids.contains(player.id) {
          assertionFailure("DOUBLE PLAYER ID")
        }
        ids.append(player.id)
      }
    #endif

    self.players = players
    self.slowMode = slowMode
  }

  public convenience init(
    contestants: Int, ai: GameAi.Type,
    localPlayer: Player,
    slowMode: Bool
  ) {
    let contestantPlayers = (0 ..< contestants).map { index in
      Player(
        name: "West (Unfair)",
        position: Position.allCases.filter { $0 != localPlayer.position }[index],
        ai: ai.init()
      )
    }

    self.init(players: contestantPlayers + [localPlayer], slowMode: slowMode)
  }

  var lastCard: Card? {
    table.lastCard
  }

  var notDonePlayers: [Player] {
    Array(players.filter { !$0.done })
  }

  public var done: Bool {
    notDonePlayers.count == 1
  }

  private func getEndState(player: Player) -> EndState? {
    let sorted = players.sorted {
      let left = $0.done ? $0.turns.count : Int.max
      let right = $1.done ? $1.turns.count : Int.max
      return left < right
    }

    guard let order = sorted.firstIndex(of: player) else {
      return nil
    }

    if order == 0 {
      return .winner
    } else {
      return .place(order + 1)
    }
  }

  private func getPlayerSnapshot(
    _ obscure: Bool, player: Player,
    includeEndState: Bool
  ) -> TurnRequest {
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
    GameSnapshot(
      deckCards: deck.cards.map { .hidden(id: $0.id) },
      players: players.map {
        getPlayerSnapshot($0.id != uuid, player: $0, includeEndState: includeEndState)
      }.orderPosition(for: uuid),
      tableCards: .init(open: table, limit: 5),
      burntCards: burnt.map { .hidden(id: $0.id) },
      playersOnTurn: playersOnTurn,
      requestFor: uuid,
      beginDate: beginDate,
      endDate: endDate
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
      logger.info("REQUEST beginMove for \(player.ai)")
      let (card1, card2, card3) = try await player.ai
        .beginMove(request: req, snapshot: getSnapshot(for: player.id, includeEndState: false))

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

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  func commitTurn(
    playerIndex: Int,
    player oldP: Player,
    numberCalled: Int, previousError: PlayerError?
  ) async throws -> (Player, TurnNext?) {
    var player = oldP

    try Task.checkCancellation()

    guard !player.done, !done, numberCalled < 100 else {
      return (player, nil)
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
      logger.info("REQUEST MOVE for \(player.ai)")
      let turn = try await player.ai.move(
        request: req,
        snapshot: getSnapshot(for: player.id, includeEndState: false)
      )

      do {
        try turn.verify()
        try await sendRender(error: previousError)
      } catch {
        if !type(of: player.ai).algoName.contains("UserInputAI") {
          logger
            .error(
              "TURN IS NOT POSSIBLE \(numberCalled), \(player.ai.algoName), \(String(describing: player.phase)), \(String(describing: turn)), \(String(describing: req.privatePossibleTurns()))"
            )
          assertionFailure("This is not possible \(type(of: player.ai))")
        }
        try await sendRender(error: error as? PlayerError ?? PlayerError
          .turnNotPossible(turn: turn))

        let (player, turnNext) = try await commitTurn(
          playerIndex: playerIndex,
          player: player,
          numberCalled: numberCalled + 1,
          previousError: (error as? PlayerError) ?? PlayerError
            .turnNotPossible(turn: turn)
        )
        return (player, .turnNext(turn, turnNext))
      }

      guard req.privatePossibleTurns().contains(turn) else {
        if !type(of: player.ai).algoName.contains("UserInputAI") {
          logger
            .error(
              "TURN IS NOT POSSIBLE \(numberCalled), \(player.ai.algoName), \(String(describing: player.phase)), \(String(describing: turn)), \(String(describing: req.privatePossibleTurns()))"
            )
          assertionFailure("This is not possible \(type(of: player.ai))")
        }

        let (player, turnNext) = try await commitTurn(
          playerIndex: playerIndex,
          player: player,
          numberCalled: numberCalled + 1,
          previousError: PlayerError.turnNotPossible(turn: turn)
        )

        return (player, .turnNext(turn, turnNext))
      }

      playerAndError[player.id] = nil
      switch turn {
      case let .closedCardIndex(index):
        if player.phase == .tableClosed {
          let previousTable = table
          let card = player.closedTableCards[index - 1]

          player.closedTableCards
            .remove(at: player.closedTableCards.firstIndex(of: card)!)

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
              let (player, turnNext) = try await commitTurn(
                playerIndex: playerIndex,
                player: player,
                numberCalled: numberCalled + 1,
                previousError: previousError ??
                  PlayerError.closedCardFailed(lastApplied)
              )

              return (player, .turnNext(turn, turnNext))
            }
          }
        } else {
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

          for turn in possibleBeurt {
            player.handCards.remove(at: player.handCards.firstIndex(of: turn)!)
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
          for turn in possibleBeurt {
            player.openTableCards.remove(at: player.openTableCards.firstIndex(of: turn)!)
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

        let (player, turnNext) = try await commitTurn(
          playerIndex: playerIndex,
          player: player,
          numberCalled: 0, previousError: nil
        )
        return (player, .turnNext(turn, turnNext))
      }

      if lastCard?.number == .ten {
        updatePlayer(player: player)
        try await sendRender(error: previousError)
        await playDelayIfNeeded(multiplier: 2)

        burnt += table
        table = []

        try await sendRender(error: previousError)

        if rules.contains(.againAfterGoodBehavior), !player.done, !done {
          let (player, turnNext) = try await commitTurn(
            playerIndex: playerIndex,
            player: player,
            numberCalled: 0, previousError: nil
          )
          return (player, .turnNext(turn, turnNext))
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
        updatePlayer(player: player)
        try await sendRender(error: previousError)
        await playDelayIfNeeded(multiplier: 2)

        burnt.append(contentsOf: table)
        table = []
        try await sendRender(error: previousError)
        if rules.contains(.againAfterGoodBehavior), !player.done, !done {
          let (player, turnNext) = try await commitTurn(
            playerIndex: playerIndex,
            player: player,
            numberCalled: 0, previousError: nil
          )
          return (player, .turnNext(turn, turnNext))
        }
      }
      return (player, .turn(turn))

    } catch {
      try Task.checkCancellation()
      try await sendRender(error: error as? PlayerError ?? previousError)

      let (player, turnNext) = try await commitTurn(
        playerIndex: playerIndex,
        player: player,
        numberCalled: numberCalled + 1,
        previousError: error as? PlayerError
      )
      return (player, turnNext)
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
        removePlayerOnSet(player: player)
        await updatePlayer(player: newPlayer)
        do {
          try await checkIntegrity()
          try await sendRender(error: nil)
        } catch {
          assertionFailure("\(error)")
        }
      } catch {
        assertionFailure("\(error)")
      }
//        }
//      }
    }
  }

  var lastFirstCardAndPlayerUUID: ([Card], UUID)?

  private func checkStalledCard(_ player: UUID) async throws {
    if let lastFirstCardAndPlayerUUID = lastFirstCardAndPlayerUUID,
       lastFirstCardAndPlayerUUID.0 == table,
       lastFirstCardAndPlayerUUID.1 == player
    {
      try await sendRender(error: nil)
      await playDelayIfNeeded()

      burnt += table
      table = []

      try await sendRender(error: nil)
      await playDelayIfNeeded()
    }
  }

  private func saveStalledCard(_ player: UUID) {
    if table.count <= 4 {
      if !table.contains(where: { $0.number != table.first?.number }) {
        if let lastFirstCardAndPlayerUUID = lastFirstCardAndPlayerUUID,
           lastFirstCardAndPlayerUUID.0 == table
        {
          return
        }

        lastFirstCardAndPlayerUUID = (table, player)
      } else { lastFirstCardAndPlayerUUID = nil }
    } else { lastFirstCardAndPlayerUUID = nil }
  }

  func turn(number: Int = 0) async throws {
    try Task.checkCancellation()

    for (index, player) in players.enumerated() {
      try Task.checkCancellation()
      if !player.done {
        try await checkStalledCard(player.id)

        playersOnTurn.insert(player.id)

        let (player, turn) = try await commitTurn(
          playerIndex: index, player: player,
          numberCalled: 0, previousError: nil
        )
        var newPlayer = player
        if let turn = turn {
          newPlayer.turns.append(turn)
        }
        players[index] = newPlayer
        do {
          try checkIntegrity()
        } catch {
          assertionFailure("checkIntegrity: \(error)")
        }
        playersOnTurn.remove(player.id)

        saveStalledCard(player.id)

        try await sendRender(error: nil)
      }
    }
    if number > 1000 {
      logger
        .error(
          "ERROR! GAME REACHED MAXIMUM OF 1000 TURNS! \(String(describing: getSnapshot(for: nil, includeEndState: true)))"
        )
      throw PlayerError.debug("GAME REACHED MAXIMUM OF 1000 TURNS!")
    }

    if !done {
      return try await turn(number: number + 1)
    }
  }

  func pickDonePlayers() -> [Player] {
    players.filter { el -> Bool in
      el.done
    }
  }

  func shouldDoAnotherRound() -> Bool {
    pickDonePlayers().count != (players.count - 1) && pickDonePlayers().count != players
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
    players.sortPlayerLowestCard()

    try Task.checkCancellation()
    try await turn()

    try Task.checkCancellation()
    try await sendRender(error: nil, includeEndState: true)
    endDate = Date()

    let endSnapshot = getSnapshot(for: nil, includeEndState: true)

    asyncDetached {
      do {
        try await saveSnapshot(endSnapshot)
      } catch {
        logger.error("Error saving snapshot")
      }
    }
    return endSnapshot
  }

  private func saveSnapshot(_ snapshot: GameSnapshot) async throws {
    let data = try JSONEncoder().encode(snapshot)
    try data
      .write(to: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("game-\(beginDate.timeIntervalSince1970).json"))

    #if !os(Linux)
    var request = URLRequest(url: URL(string: "https://shitheaden-api.harke.ma/playedGame")!)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "content-type")
    let task = URLSession.shared.uploadTask(with: request, from: data)
    task.resume()
    #endif
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

      for card in table {
        if let found = pastCards.first(where: { $0.0 == card }) {
          throw PlayerError.integrityDoubleCardEncountered(found.0)
        }
        pastCards.append((card, "table"))
      }

      for card in deck.cards {
        if let card = pastCards.first(where: { $0.0 == card }) {
          throw PlayerError.integrityDoubleCardEncountered(card.0)
        }
        pastCards.append((card, "deck"))
      }

      for card in burnt {
        if let card = pastCards.first(where: { $0.0 == card }) {
          throw PlayerError.integrityDoubleCardEncountered(card.0)
        }
        pastCards.append((card, "burnt"))
      }

      if pastCards.count != 52 {
        logger.error("Card count: \(pastCards.count)")
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
    contains("UserInputAI")
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
        newElement.position = Position.allCases
          .shifted(by: offsetForPlayer - offsetForZuid)[index]
        return newElement
      }
  }
}
