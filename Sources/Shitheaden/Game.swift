//
//  Game.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Foundation
import ShitheadenShared

public typealias Table = [Card]

public actor Game {
  public init(players: [Player]) {
    self.players = players
  }

  var deck = Deck(cards: [])
  public var players = [Player]()
  public private(set) var table = Table()
  var burnt = [Card]()
  var turns = [(String, Turn)]()

  let rules = Rules.all

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

  func commitTurn(
    playerIndex: Int,
    player oldP: Player,
    render: (Game) async -> Void,
    numberCalled: Int
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

    let turn = await player.ai.move(request: req)

    try! turn.verify()

    guard req.possibleTurns().contains(turn) else {
//      print(
//        "ISSUE!",
//        oldPlayer.phase,
//        turn,
//        req.possibleTurns(),
//        player.handCards,
//        player.openTableCards,
//        player.closedTableCards,
//        player.hasPutCardsOpen,
//        player.done
//      )
      print("NO POSSIBLE", numberCalled, await player.ai.algoName, player.phase, turn, req.possibleTurns())
      assertionFailure("This is not possible")
      return await commitTurn(
        playerIndex: playerIndex,
        player: player,
        render: render,
        numberCalled: numberCalled + 1
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

      case .putOnTable:
        break
      }

    case .pass:
      player.handCards.append(contentsOf: table)
      table = []

    case let .putOnTable(card1, card2, card3):
      player.handCards.remove(at: player.handCards.firstIndex(of: card1)!)
      player.handCards.remove(at: player.handCards.firstIndex(of: card2)!)
      player.handCards.remove(at: player.handCards.firstIndex(of: card3)!)

      player.openTableCards.append(card1)
      player.openTableCards.append(card2)
      player.openTableCards.append(card3)
      player.hasPutCardsOpen = true
    }

    turns += [(player.name, turn)]

    if turn == .pass, rules.contains(.againAfterPass), !player.done, !done {
//      printState()
      await render(self)
      return await commitTurn(
        playerIndex: playerIndex,
        player: player,
        render: render,
        numberCalled: numberCalled + 1
      )
    }

    if lastCard?.number == .ten {
      burnt += table
      table = []
//      printState()

      await render(self)
      if rules.contains(.againAfterGoodBehavior), !player.done, !done {
        return await commitTurn(
          playerIndex: playerIndex,
          player: player,
          render: render,
          numberCalled: numberCalled + 1
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
      if rules.contains(.againAfterGoodBehavior), !player.done, !done {
        return await commitTurn(
          playerIndex: playerIndex,
          player: player,
          render: render,
          numberCalled: numberCalled + 1
        )
      }
    }

    return player
  }

  func beurt(render: (Game) async -> Void) async {
    for (index, player) in players.enumerated() {
      if !player.done {
      players[index] = await commitTurn(playerIndex: index, player: player, render: render,
                                        numberCalled: 0)
      try! checkIntegrity()
      }
      await render(self)
    }
    if !done {
      return await beurt(render: render)
    }
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

  func startRound(render: @escaping (Game) async -> Void) async {
    resetBeurten()

    shuffle()
    deel()
//    printState()
    await render(self)
    await beurt(render: render)

//    finishRound()
//    printEndState(render: render)
  }

  private func startGameRec(
    render: @escaping (Game) async -> Void
  ) async {
    await startRound(render: render)
  }

  public func startGame(render: @escaping (Game) async -> Void) async {
    await startGameRec(
      render: render
    )
  }

  func checkIntegrity() throws {
//#if DEBUG
      var pastCards = [(Card, String)]()

      for player in players {
        for handCard in player.handCards {
          if pastCards.contains { $0.0 == handCard } {
            try PlayerError(text: "DOUBLE CARD ENCOUNTERED")
          }
          pastCards.append((handCard, "\(player.name):hand"))
        }
        for openTableCard in player.openTableCards {
          if pastCards.contains { $0.0 == openTableCard } {
            try PlayerError(text: "DOUBLE CARD ENCOUNTERED")
          }
          pastCards.append((openTableCard, "\(player.name):openTableCard"))
        }
        for closedTableCard in player.closedTableCards {
          if pastCards.contains { $0.0 == closedTableCard } {
            try PlayerError(text: "DOUBLE CARD ENCOUNTERED")
          }
          pastCards.append((closedTableCard, "\(player.name):closedTableCard"))
        }
      }

      for c in table {
        if let found = pastCards.first(where: { $0.0 == c }) {
          print("found", found)
          try PlayerError(text: "DOUBLE CARD ENCOUNTERED")
        }
        pastCards.append((c, "table"))
      }

      for c in deck.cards {
        if pastCards.contains(where: { $0.0 == c }) {
          try PlayerError(text: "DOUBLE CARD ENCOUNTERED")
        }
        pastCards.append((c, "deck"))
      }

      for c in burnt {
        if pastCards.contains { $0.0 == c } {
          try PlayerError(text: "DOUBLE CARD ENCOUNTERED")
        }
        pastCards.append((c, "burnt"))
      }

      if pastCards.count != 52 {
        print(pastCards.count)
        print(turns)
        try PlayerError(text: "SHOULD HAVE 52 CARDS!")
      }

//#endif
  }
}

extension Table {
  var lastCard: Card? {
    return lazy.filter { $0.number != .three }.last
  }
}
