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
import AsyncAwaitHelpers

// swiftlint:disable:next type_body_length
public actor Game {
  private let logger = Logger(label: "runtime.Game")

  private let gameId = UUID()
  private let beginDate = Date().timeIntervalSince1970
  private var endDate: TimeInterval?

  private(set) var deck = Deck()
  private var players = [Player]()
  private(set) var table = Table()
  private(set) var burnt = [Card]()

  #if DEBUG
    public func privateSetBurnt(_ cards: [Card]) {
      burnt = cards
    }

    func set(deck: Deck) {
      self.deck = deck
    }
  #endif

  private var turns = [UserAndTurn]()
  private let rules: Rules
  private var slowMode = false
  private var playersOnTurn = Set<UUID>()
  private var playerAndError = [UUID: PlayerError]()

  public init(
    players: [Player],
    rules: Rules,
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
    self.rules = rules
    self.slowMode = slowMode
  }

  public convenience init(
    contestants: Int,
    ai: GameAi.Type,
    localPlayer: Player,
    rules: Rules,
    slowMode: Bool
  ) {
    let contestantPlayers = (0 ..< contestants).map { index in
      Player(
        name: "CPU \(index + 1)",
        position: Position.allCases.filter { $0 != localPlayer.position }[index],
        ai: ai.make()
      )
    }

    self.init(
      players: contestantPlayers + [localPlayer],
      rules: rules,
      slowMode: slowMode
    )
  }

  public init(snapshot: GameSnapshot, localPlayerAi: GameAi, otherAi: GameAi) {
    deck = Deck(cards: snapshot.deckCards.unobscure())
    burnt = snapshot.burntCards.unobscure()
    table = snapshot.tableCards.unobscure()

    players = snapshot.players.map {

      let ai = $0.algoName.isUser ? localPlayerAi : otherAi

      let restoredPlayer = Player(
        id: $0.id,
        name: $0.name,
        position: $0.position,
        ai: ai,
        handCards: $0.handCards.unobscure(),
        openTableCards: $0.openTableCards.unobscure(),
        closedTableCards: $0.closedCards.unobscure(),
        turns: [] // FIXME
      )

      return restoredPlayer
    }
    slowMode = true
    self.rules = snapshot.rules
  }

  private var lastCard: Card? {
    table.lastCard
  }

  private var notDonePlayers: [Player] {
    Array(players.filter { !$0.done })
  }

  public var done: Bool {
    notDonePlayers.count == 1
  }

  private func getEndState(player: Player) -> EndPlace? {
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
    obscure: Bool, player: Player,
    includeEndState: Bool
  ) -> TurnRequest {
    if obscure, !includeEndState {
      return TurnRequest(
        rules: rules,
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
        rules: rules,
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
        getPlayerSnapshot(obscure: $0.id != uuid, player: $0, includeEndState: includeEndState)
      }.orderPosition(for: uuid),
      tableCards: .init(open: table, limit: 5),
      burntCards: burnt.map { .hidden(id: $0.id) },
      playersOnTurn: playersOnTurn,
      requestFor: uuid,
      beginDate: beginDate,
      endDate: endDate,
      turns: includeEndState ? turns : [],
      rules: rules
    )
  }

  private func getPersistenceSnapshot() -> GameSnapshot {
    return GameSnapshot(
      deckCards: deck.cards.map { .card(card: $0) },
      players: players.map { player in
        TurnRequest(
          rules: rules,
          id: player.id,
          name: player.name,
          handCards: .init(open: player.handCards),
          openTableCards: .init(open: player.openTableCards),
          lastTableCard: table.lastCard,
          closedCards: .init(open: player.closedTableCards),
          phase: player.phase,
          tableCards: .init(open: table, limit: 5),
          deckCards: .init(open: deck.cards),
          algoName: player.ai.algoName,
          done: player.done,
          position: player.position,
          isObscured: false,
          playerError: playerAndError[player.id],
          endState: nil
        )
      },
      tableCards: table.map { .card(card: $0) },
      burntCards: burnt.map { .card(card: $0) },
      playersOnTurn: playersOnTurn,
      requestFor: nil,
      beginDate: beginDate,
      endDate: endDate,
      turns: turns,
      rules: rules
    )
  }

  private func savePersistenceSnaphot() async {
    await Persistence.saveSnapshot(snapshot: getPersistenceSnapshot())
  }

  private func shuffle() {
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
      players[index].sortCardsHandImportance()
      players[index].closedTableCards = [deck.draw()!, deck.draw()!, deck.draw()!]
    }
  }

  private func commitBeginTurn(
    playerIndex: Int,
    player oldP: Player,
    numberCalled: Int,
    previousError: PlayerError?
  ) async throws -> Player {
    var player = oldP

    try Task.checkCancellation()

    updatePlayer(player: player)

    let req = TurnRequest(
      rules: rules,
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
      player.sortCardsHandImportance()

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

  private func isUserPlayerUnfinished() -> Bool {
    !(players.first { $0.ai.algoName.isUser }?.done ?? true)
  }

  private func playDelayIfNeeded(multiplier: Double = 1.0) async throws {
    if slowMode, isUserPlayerUnfinished() {
      try await Task.sleep(time: (0.5 * multiplier))
    }
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private func commitTurn(
    playerIndex: Int,
    player oldP: Player,
    numberCalled: Int, previousError: PlayerError?
  ) async throws -> (Player, TurnNext?) {
    var player = oldP

    try Task.checkCancellation()

    guard !player.done, !done, numberCalled < 100 else {
      return (player, nil)
    }

    updatePlayer(player: player)

    let req = TurnRequest(
      rules: rules,
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

    try await playDelayIfNeeded()

    try await sendRender(error: previousError)

    do {
      logger.info("REQUEST MOVE for \(player.ai)")
      let turn = try await player.ai.move(
        request: req,
        snapshot: getSnapshot(for: player.id, includeEndState: false)
      )

      do {
        try turn.verify()

        if !type(of: player.ai).algoName.contains("UserInputAI") {
          try await playDelayIfNeeded()
        }

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
      let previousTable = table
      switch turn {
      case let .closedCardIndex(index):
        if player.phase == .tableClosed {
          let card = player.closedTableCards[index - 1]

          player.closedTableCards
            .remove(at: player.closedTableCards.firstIndex(of: card)!)

          table += [card]

          if let lastTable = previousTable.filter({ $0.number != .three }).last,
             let lastApplied = table.filter({ $0.number != .three }).last,
             !lastTable.number.afters.contains(lastApplied.number)
          {
            try await sendRender(error: previousError)
            try await playDelayIfNeeded(multiplier: 2)

            player.handCards.append(contentsOf: table)
            player.sortCardsHandImportance()
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
          } else if player.ai.algoName.isUser {
            updatePlayer(player: player)
            try await sendRender(error: previousError)
            try await Task.sleep(time: 1)
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
          player.sortCardsHandImportance()

        case .tableOpen:
          assert(!possibleBeurt.contains { !player.openTableCards.contains($0) }, "WTF")
          for turn in possibleBeurt {
            player.openTableCards.remove(at: player.openTableCards.firstIndex(of: turn)!)
          }

          if let lastTable = previousTable.filter({ $0.number != .three }).last,
             let lastApplied = table.filter({ $0.number != .three }).last,
             !lastTable.number.afters.contains(lastApplied.number),
             rules.contains(.getCardWhenPassOpenCardTables)
          {
            try await sendRender(error: previousError)
            try await playDelayIfNeeded(multiplier: 2)

            player.handCards.append(contentsOf: table)
            player.sortCardsHandImportance()
            table = []
            updatePlayer(player: player)
            try await sendRender(error: previousError)
            if rules.contains(.againAfterPass) {
              let (player, turnNext) = try await commitTurn(
                playerIndex: playerIndex,
                player: player,
                numberCalled: numberCalled + 1,
                previousError: previousError ??
                  PlayerError.openCardFailed(lastApplied)
              )

              return (player, .turnNext(turn, turnNext))
            }
          }

        case .tableClosed:
          fatalError("Cannot play in this phase")
        }

      case .pass:
        player.handCards.append(contentsOf: table)
        player.sortCardsHandImportance()
        table = []
      }

      turns += [UserAndTurn(uuid: player.id.uuidString, turn: turn)]

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
        try await playDelayIfNeeded(multiplier: 2)

        burnt += table
        table = []

        try await sendRender(error: previousError)

        if !player.done, !done {
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
        try await playDelayIfNeeded(multiplier: 2)

        burnt += table
        table = []
        try await sendRender(error: previousError)
        if rules.contains(.againAfterPlayingFourCards), !player.done, !done {
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

  nonisolated func beginRound() async throws {
    try Task.checkCancellation()

    await whenAll(await players.enumerated().map { [weak self] (index, player) in
      return { [weak self] in
        guard let self = self else { return }
        do {
          await self.startPlayerOnSet(player: player)

          let newPlayer = try await self.commitBeginTurn(
            playerIndex: index,
            player: player,
            numberCalled: 0,
            previousError: nil
          )
          await self.removePlayerOnSet(player: player)
          await self.updatePlayer(player: newPlayer)
          do {
            try await self.checkIntegrity()
            try await self.sendRender(error: nil)
          } catch {
            assertionFailure("\(error)")
          }
        } catch {
          self.logger.error("Error: \(error)")
        }
      }
    })
  }

  private var lastFirstCardAndPlayerUUID: ([Card], UUID)?

  private func checkStalledCard(_ player: UUID) async throws {
    guard let lastFirstCardAndPlayerUUID = lastFirstCardAndPlayerUUID,
          lastFirstCardAndPlayerUUID.0.equalsIgnoringOrder(as: table),
          lastFirstCardAndPlayerUUID.1 == player
    else { return }

    try await sendRender(error: nil)
    try await playDelayIfNeeded()

    burnt += table
    table = []

    try await sendRender(error: nil)
    try await playDelayIfNeeded()
  }

  private func saveStalledCard(_ player: UUID) {
    if !table.isEmpty, table.count <= 4,
       !table.contains(where: { $0.number != table.first?.number })
    {
      if let lastFirstCardAndPlayerUUID = lastFirstCardAndPlayerUUID,
         lastFirstCardAndPlayerUUID.0.equalsIgnoringOrder(as: table)
      {
        return
      }

      lastFirstCardAndPlayerUUID = (table, player)

    } else {
      lastFirstCardAndPlayerUUID = nil
    }
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

    if isUserPlayerUnfinished() {
      Task { await savePersistenceSnaphot() }
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

  private func pickDonePlayers() -> [Player] {
    players.filter { el -> Bool in
      el.done
    }
  }

  private func shouldDoAnotherRound() -> Bool {
    pickDonePlayers().count != (players.count - 1) && pickDonePlayers().count != players
      .count
  }

  private func resetBeurten() {
    for index in players.indices {
      players[index].turns = []
    }
  }

  public func startGame() async throws -> EndGameSnapshot {
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
    endDate = Date().timeIntervalSince1970
    try await Task.sleep(time: 1)
    try await sendRender(error: nil, includeEndState: true)

    Persistence.invalidateSnapshot()

    return EndGameSnapshot(
      gameId: gameId,
      snapshot: getSnapshot(for: nil, includeEndState: true),
      signature: (try? await Signature.getSignature()) ?? "NO_SIGNATURE"
    )
  }

  public func resume() async throws -> EndGameSnapshot {
    try Task.checkCancellation()
    try await turn()

    try Task.checkCancellation()
    endDate = Date().timeIntervalSince1970
    try await Task.sleep(time: 1)
    try await sendRender(error: nil, includeEndState: true)

    Persistence.invalidateSnapshot()

    return EndGameSnapshot(
      gameId: gameId,
      snapshot: getSnapshot(for: nil, includeEndState: true),
      signature: (try? await Signature.getSignature()) ?? "NO_SIGNATURE"
    )
  }

  private func checkIntegrity() throws {
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
