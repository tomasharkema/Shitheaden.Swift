//
//  Game.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Foundation
import ShitheadenShared

public final actor Game {
  private(set) var deck = Deck(cards: [])
  var players = [Player]()
  private(set) var table = Table()
  private(set) var burnt = [Card]()
  var turns = [(String, Turn)]()
  let rules = Rules.all
  var slowMode = false
  var playerOnTurn: UUID?

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

  var winner: Player? {
    done ? players.max { $0.turns.count < $1.turns.count } : nil
  }

  private func getPlayerSnapshot(_ obscure: Bool, player: Player) -> ObscuredPlayerResult {
    if obscure {
      return .obscured(ObsucredTurnRequest(
        id: player.id, name: player.name,
        numberOfHandCards: player.handCards.count,
        openTableCards: player.openTableCards,
        lastTableCard: table.lastCard,
        numberOfClosedTableCards: player.closedTableCards
          .count,
        phase: player.phase,
        amountOfTableCards: table.count,
        amountOfDeckCards: deck.cards.count,
        algoName: player.ai.algoName,
        done: player.done,
        position: player.position
      ))
    } else {
      return .player(TurnRequest(
        id: player.id, name: player.name,
        handCards: player.handCards,
        openTableCards: player.openTableCards,
        lastTableCard: table.lastCard,
        numberOfClosedTableCards: player.closedTableCards.count,
        phase: player.phase,
        amountOfTableCards: table.count,
        amountOfDeckCards: deck.cards.count,
        algoName: player.ai.algoName,
        done: player.done,
        position: player.position
      ))
    }
  }

  public func getSnapshot(for uuid: UUID?) -> GameSnapshot {
    return GameSnapshot(
      numberOfDeckCards: deck.cards.count,
      players: players.map {
        getPlayerSnapshot($0.id != uuid, player: $0)
      },
      latestTableCards: table.suffix(5), numberOfTableCards: table.count,
      numberOfBurntCards: burnt.count,
      playerOnTurn: playerOnTurn ?? UUID(),
      winner: winner.map { getPlayerSnapshot(false, player: $0) }
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
  ) async -> Player {
    var player = oldP

    player.sortCards()

    let req = TurnRequest(
      id: player.id, name: player.name,
      handCards: player.handCards,
      openTableCards: player.openTableCards,
      lastTableCard: table.lastCard,
      numberOfClosedTableCards: player.closedTableCards.count,
      phase: player.phase,
      amountOfTableCards: table.count,
      amountOfDeckCards: deck.cards.count,
      algoName: player.ai.algoName,
      done: player.done,
      position: player.position
    )

    playerOnTurn = player.id

    await sendRender(error: previousError)

    do {
      let (card1, card2, card3) = try await player.ai.beginMove(request: req, previousError: previousError)


    // verify turn
    if [card1, card2, card3].contains(where: {
      !player.handCards.contains($0)
    }) {
      fatalError("NOT EXISTING IN HAND!")
    }

    player.handCards.remove(at: player.handCards.firstIndex(of: card1)!)
    player.handCards.remove(at: player.handCards.firstIndex(of: card2)!)
    player.handCards.remove(at: player.handCards.firstIndex(of: card3)!)

    player.openTableCards.append(card1)
    player.openTableCards.append(card2)
    player.openTableCards.append(card3)

    return player
    } catch {

      await sendRender(error: (error as? PlayerError) ?? previousError)

      return await commitBeginTurn(
        playerIndex: playerIndex,
        player: oldP,
        numberCalled: numberCalled,
        previousError: (error as? PlayerError) ?? previousError
      )
    }
  }

  private func sendRender(error: PlayerError?) async {
    for player in players {
      let error = player.id == playerOnTurn ? error : nil
      await player.ai.render(snapshot: getSnapshot(for: player.id), error: error)
    }
  }

  func commitTurn(
    playerIndex: Int,
    player oldP: Player,
    numberCalled: Int, previousError: PlayerError?
  ) async -> Player {
    var player = oldP

    guard !player.done, !done, numberCalled < 100 else {
      return player
    }

    player.sortCards()

    let req = TurnRequest(
      id: player.id, name: player.name,
      handCards: player.handCards,
      openTableCards: player.openTableCards,
      lastTableCard: table.lastCard,
      numberOfClosedTableCards: player.closedTableCards.count,
      phase: player.phase,
      amountOfTableCards: table.count,
      amountOfDeckCards: deck.cards.count,
      algoName: player.ai.algoName,
      done: player.done,
      position: player.position
    )
    if slowMode {
      let userPlayer = players.first { $0.ai.algoName.isUser }
      if !(userPlayer?.done ?? true) {
        await delay(for: .now() + 0.5)
      }
    }

    playerOnTurn = player.id

    await sendRender(error: previousError)

    do {

      let turn = try await player.ai.move(request: req, previousError: previousError)

    do {
      try turn.verify()
      await sendRender(error: previousError)
    } catch {

      if !type(of: player.ai).algoName.contains("UserInputAI") {
        #if DEBUG
          print(
            "NO POSSIBLE",
            numberCalled,
            player.ai.algoName,
            player.phase,
            turn,
            req.possibleTurns()
          )

          assertionFailure("This is not possible \(type(of: player.ai))")
        #endif
      }
      await sendRender(error: error as? PlayerError ??
                       PlayerError(text: "\(turn.explain) is niet mogelijk..."))
      return await commitTurn(
        playerIndex: playerIndex,
        player: player,
        numberCalled: numberCalled + 1,
        previousError: error as? PlayerError ??
          PlayerError(text: "\(turn.explain) is niet mogelijk...")
      )
    }

    guard req._possibleTurns().contains(turn) else {
      if !type(of: player.ai).algoName.contains("UserInputAI") {
        #if DEBUG
          print(
            "NO POSSIBLE",
            numberCalled,
            player.ai.algoName,
            player.phase,
            turn,
            req._possibleTurns()
          )
        #endif
        assertionFailure("This is not possible \(type(of: player.ai))")
      }
      return await commitTurn(
        playerIndex: playerIndex,
        player: player,
        numberCalled: numberCalled + 1,
        previousError: PlayerError(text: "\(turn.explain) is niet mogelijk...")
      )
    }

    player.turns.append(turn)

    switch turn {
    case let .closedCardIndex(index):
      if player.phase == .tableClosed {
        let previousTable = table
        let card = player.closedTableCards[index - 1]

        player.closedTableCards.remove(at: player.closedTableCards.firstIndex(of: card)!)

        table += [card]

        if let lastTable = previousTable.filter({ $0.number != .three }).last,
           let lastApplied = table.filter({ $0.number != .three }).last,
           !lastTable.afters.contains(lastApplied)
        {
          player.handCards.append(contentsOf: table)
          table = []
          updatePlayer(player: player)
          await sendRender(error: previousError)
          if rules.contains(.againAfterPass) {
            return await commitTurn(
              playerIndex: playerIndex,
              player: player,
              numberCalled: numberCalled + 1,
              previousError: previousError ??
                PlayerError(text: "Je dichte kaart was \(lastApplied)... Je mag opnieuw!")
            )
          }
        }
      } else {
//        throw PlayerError(text: "Can not throw closedCardIndex")
        fatalError("Can not throw closedCardIndex")
      }
    case let .play(possibleBeurt):
      table.append(contentsOf: possibleBeurt)

      switch player.phase {
      case .hand:
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
        for p in possibleBeurt {
          player.openTableCards.remove(at: player.openTableCards.firstIndex(of: p)!)
        }

      case .tableClosed:
//        throw PlayerError(text: "Cannot play in this phase")
        fatalError("Cannot play in this phase")
      }

    case .pass:
      player.handCards.append(contentsOf: table)
      table = []
    }

    turns += [(player.name, turn)]

    await sendRender(error: previousError)

    if turn == .pass, rules.contains(.againAfterPass), !player.done, !done {
//      printState()
      await sendRender(error: previousError)
      updatePlayer(player: player)
      return await commitTurn(
        playerIndex: playerIndex,
        player: player,
        numberCalled: 0, previousError: nil
      )
    }

    if lastCard?.number == .ten {
      burnt += table
      table = []

      await sendRender(error: previousError)
      updatePlayer(player: player)

      if rules.contains(.againAfterGoodBehavior), !player.done, !done {
        return await commitTurn(
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
      burnt.append(contentsOf: table)
      table = []
      await sendRender(error: previousError)
      updatePlayer(player: player)
      if rules.contains(.againAfterGoodBehavior), !player.done, !done {
        return await commitTurn(
          playerIndex: playerIndex,
          player: player,
          numberCalled: 0, previousError: nil
        )
      }
    }
    return player

    } catch {
      await sendRender(error: error as? PlayerError ?? previousError)

      return await commitTurn(
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

  func beginRound() async {
//    await withTaskGroup(of: Void.self) { g in
    for (index, player) in players.enumerated() {
//        g.async {
      let newPlayer = await commitBeginTurn(
        playerIndex: index,
        player: player,
        numberCalled: 0,
        previousError: nil
      )
      updatePlayer(player: newPlayer)
      try! checkIntegrity()
      await sendRender(error: nil)
    }
//      }
//    }
  }

  func turn(n: Int = 0) async {
    for (index, player) in players.enumerated() {
      if !player.done {
        players[index] = await commitTurn(
          playerIndex: index, player: player,
          numberCalled: 0, previousError: nil
        )
        try! checkIntegrity()
        await sendRender(error: nil)
      }
    }
    if n > 1000 {
      print("ERROR! GAME REACHED MAXIMUM OF 1000 TURNS! \(getSnapshot(for: nil))")
      return
    }

    if !done {
      return await turn(n: n + 1)
    }
  }

  func sortPlayerLowestCard() {
    guard let player = players
      .min(by: {
        (($0.handCards.filter { $0.number >= .four }.min { $0 > $1 })?.order ?? 0)
          >
          (($1.handCards.filter { $0.number >= .four }.min { $0 > $1 })?.order ?? 0)
      })
    else {
      return
    }
    guard let place = players.firstIndex(of: player) else {
      return
    }
    let newPlayers = players.shifted(by: -place)
    players = newPlayers
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

  public func startGame() async -> GameSnapshot {
    resetBeurten()

    await sendRender(error: nil)

    shuffle()
    deel()
    await sendRender(error: nil)
    await beginRound()

    sortPlayerLowestCard()

    await turn()

    return getSnapshot(for: nil)
  }

  func checkIntegrity() throws {
    #if DEBUG
      var pastCards = [(Card, String)]()

      for player in players {
        for handCard in player.handCards {
          if pastCards.contains(where: { $0.0 == handCard }) {
            throw PlayerError(text: "DOUBLE CARD ENCOUNTERED")
          }
          pastCards.append((handCard, "\(player.name):hand"))
        }
        for openTableCard in player.openTableCards {
          if pastCards.contains(where: { $0.0 == openTableCard }) {
            throw PlayerError(text: "DOUBLE CARD ENCOUNTERED")
          }
          pastCards.append((openTableCard, "\(player.name):openTableCard"))
        }
        for closedTableCard in player.closedTableCards {
          if pastCards.contains(where: { $0.0 == closedTableCard }) {
            throw PlayerError(text: "DOUBLE CARD ENCOUNTERED")
          }
          pastCards.append((closedTableCard, "\(player.name):closedTableCard"))
        }
      }

      for c in table {
        if let found = pastCards.first(where: { $0.0 == c }) {
          print("found", found)
          throw PlayerError(text: "DOUBLE CARD ENCOUNTERED")
        }
        pastCards.append((c, "table"))
      }

      for c in deck.cards {
        if pastCards.contains(where: { $0.0 == c }) {
          throw PlayerError(text: "DOUBLE CARD ENCOUNTERED")
        }
        pastCards.append((c, "deck"))
      }

      for c in burnt {
        if pastCards.contains(where: { $0.0 == c }) {
          throw PlayerError(text: "DOUBLE CARD ENCOUNTERED")
        }
        pastCards.append((c, "burnt"))
      }

      if pastCards.count != 52 {
        print(pastCards.count)
        print(turns)
        throw PlayerError(text: "SHOULD HAVE 52 CARDS!")
      }

    #endif
  }

  deinit {
    print("DEINIT")
  }
}

public extension String {
  nonisolated var isUser: Bool {
    return contains("UserInputAI")
  }
}
