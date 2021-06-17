//
//  Game.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Foundation
import ShitheadenShared

public actor Game {
  public private(set) var deck = Deck(cards: [])
  public var players = [Player]()
  public private(set) var table = Table()
  public private(set) var burnt = [Card]()
  var turns = [(String, Turn)]()
  let render: (Game, Bool) async -> Void
  let rules = Rules.all
  var slowMode = false

  public init(players: [Player], slowMode: Bool, render: @escaping (Game, Bool) async -> Void) {
    self.players = players
    self.render = render
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

  public var winner: Player? {
    done ? players.max { $0.turns.count < $1.turns.count } : nil
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
    playerIndex _: Int,
    player oldP: Player,
    numberCalled _: Int,
    previousError: PlayerError?
  ) async -> Player {
    var player = oldP

    player.sortCards()

    let req = await TurnRequest(
      handCards: player.handCards,
      openTableCards: player.openTableCards,
      lastTableCard: table.lastCard,
      numberOfClosedTableCards: player.closedTableCards.count,
      phase: player.phase,
      amountOfTableCards: table.count,
      amountOfDeckCards: deck.cards.count
    )

    let (card1, card2, card3) = await player.ai
      .beginMove(request: req, previousError: previousError)

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
      handCards: player.handCards,
      openTableCards: player.openTableCards,
      lastTableCard: table.lastCard,
      numberOfClosedTableCards: player.closedTableCards.count,
      phase: player.phase,
      amountOfTableCards: table.count,
      amountOfDeckCards: deck.cards.count
    )

    await render(self, true)

    if slowMode {
    let userPlayer = await players.first { $0.ai.isUser }
    if await !(userPlayer?.done ?? true) {
      await delay(for: .now() + 0.5)
    }
    }

    let turn = await player.ai.move(request: req, previousError: previousError)

    do {
      try turn.verify()
      await render(self, true)
    } catch {
      if !type(of: player.ai).algoName.contains("UserInputAI") {
        #if DEBUG
        print(
          "NO POSSIBLE",
          numberCalled,
          await player.ai.algoName,
          player.phase,
          turn,
          req.possibleTurns()
        )

        assertionFailure("This is not possible \(type(of: player.ai))")
        #endif
      }
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
          await player.ai.algoName,
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

        if let lastTable = previousTable.last, let lastApplied = table.last,
           !lastTable.afters.contains(lastApplied)
        {
          player.handCards.append(contentsOf: table)
          table = []
          await render(self, true)
          if rules.contains(.againAfterPass) {
            return await commitTurn(playerIndex: playerIndex, player: player, numberCalled: numberCalled + 1, previousError: previousError ?? PlayerError(text: "Je dichte kaart was \(lastApplied)... Je mag opnieuw!"))
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

    await render(self, true)

    if turn == .pass, rules.contains(.againAfterPass), !player.done, !done {
//      printState()
      await render(self, true)
      return await commitTurn(
        playerIndex: playerIndex,
        player: player,
        numberCalled: 0, previousError: nil
      )
    }

    if lastCard?.number == .ten {
      burnt += table
      table = []

      await render(self, true)

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
      await render(self, true)
      if rules.contains(.againAfterGoodBehavior), !player.done, !done {
        return await commitTurn(
          playerIndex: playerIndex,
          player: player,
          numberCalled: 0, previousError: nil
        )
      }
    }

    return player
  }

  private func updatePlayer(player: Player) {
    guard let index = players.firstIndex(where: { player.id == $0.id }) else {
      fatalError()
      return
    }

    players[index] = player
  }

  func beginRound() async {
//    await withTaskGroup(of: Void.self) { g in
      for (index, player) in await players.enumerated() {
//        g.async {
          await self.updatePlayer(player: await self.commitBeginTurn(
            playerIndex: index,
            player: player,
            numberCalled: 0,
            previousError: nil
          ))
          try! await self.checkIntegrity()
          await self.render(self, false)
//        }
//      }
    }
  }

  func turn() async {
    for (index, player) in players.enumerated() {
      if !player.done {
        players[index] = await commitTurn(playerIndex: index, player: player,
                                          numberCalled: 0, previousError: nil)
        try! checkIntegrity()
        await render(self, true)
      }
    }
    if !done {
      return await turn()
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

  func pickLosers() -> Set<Player> {
    var losers = Set<Player>()

    for player in players {
      if !player.done {
//        if losers.count == 0 {
        losers.insert(player)
//        } else {
//          for loser in losers {
//            if player.points < loser.points {
//              losers.removeAll()
//              losers.insert(player)
//            } else if player.points == loser.points {
//              losers.insert(player)
//            }
//          }
//        }
      }
    }

    return losers
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

  public func startGame() async {
    resetBeurten()

    await render(self, true)

    shuffle()
    deel()
//    printState()
    await render(self, true)
    await beginRound()

    sortPlayerLowestCard()

    await turn()
  }

  func checkIntegrity() throws {
//     #if DEBUG
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

//     #endif
  }
}


extension GameAi {
  nonisolated public var isUser: Bool {
    return algoName.contains("UserInputAI")
  }
}
