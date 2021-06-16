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

  func commitTurn(playerIndex: Int, player oldPlayer: Player, render: (Game) async -> ()) async -> Player {
    guard !oldPlayer.done, !done else {
      return oldPlayer
    }

    var player = oldPlayer
    player.sortCards()

    let req = TurnRequest(handCards: player.handCards, openTableCards: player.openTableCards, lastTableCard: table.lastCard, numberOfClosedTableCards: player.closedTableCards.count, phase: player.phase, amountOfTableCards: table.count, amountOfDeckCards: deck.cards.count)

    let turn = await player.ai.move(request: req)

    guard req.possibleTurns().contains(turn) else {
      print(
        "ISSUE!",
        oldPlayer.phase,
        turn,
        req.possibleTurns(),
        player.handCards,
        player.openTableCards,
        player.closedTableCards,
        player.hasPutCardsOpen,
        player.done
      )
      print("NO POSSIBLE")
      assertionFailure("This is not possible")
      return try await commitTurn(playerIndex: playerIndex, player: oldPlayer, render: render)
    }

    // let count = player.turns.filter { $0 == turn }.count
    // if count > 50 {
    //   // bail out when player is in a loop
    //   pass(playerIndex: playerIndex)
    //   return player
    // }

    player.turns.append(turn)

    switch turn {

    case .closedCardIndex(let index):

      if player.phase == .tableClosed {
        let previousTable = table
        let card = player.closedTableCards[index - 1]
        player.closedTableCards.remove(el: card)
        table = Array([table, [card]].joined())

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
      table = table + possibleBeurt

      switch player.phase {
      case .hand:
        for p in possibleBeurt {
          player.handCards.remove(el: p)
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
          player.openTableCards.remove(el: p)
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
      player.handCards.remove(el: card1)
      player.handCards.remove(el: card2)
      player.handCards.remove(el: card3)
      player.openTableCards.append(card1)
      player.openTableCards.append(card2)
      player.openTableCards.append(card3)
      player.hasPutCardsOpen = true
    }

    if turn == .pass, rules.contains(.againAfterPass), !player.done, !done {
//      printState()
      await render(self)
      return try await commitTurn(playerIndex: playerIndex, player: player, render: render)
    }

    if lastCard?.number == .ten {
      burnt += table
      table = []
//      printState()

      await render(self)
      if rules.contains(.againAfterGoodBehavior), !player.done, !done {
        return try await commitTurn(playerIndex: playerIndex, player: player, render: render)
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
        return try await commitTurn(playerIndex: playerIndex, player: player, render: render)
      }
    }

    return player
  }

  func beurt(render: (Game) async -> ()) async {
    for (index, player) in notDonePlayers.enumerated() {
      players[index] = await commitTurn(playerIndex: index, player: player, render: render)
//      printState()
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

  func startRound(render: @escaping (Game) async -> ()) async {
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
    render: @escaping (Game) async -> ()
  ) async {
    await startRound(render: render)
  }

  public func startGame(render: @escaping (Game) async -> ()) async {
    await startGameRec(
      render: render
    )
  }
}

extension Table {
  var lastCard: Card? {
    return lazy.filter { $0.number != .three }.last
  }
}

extension Array where Element == Turn {
  var includeDoubles: Set<Turn> {
    var turns = Set<Turn>()

    for el in self {
      turns.insert(el)

      if case let .play(cards) = el {
        for card in cards {
          for case let .play(otherCards) in turns {
            var a = Set([card])
            // a.insert(contentsOf: otherCards.filter { $0.number == card.number })
            for e in otherCards.filter { $0.number == card.number } {
              a.insert(e)
            }
            turns.insert(Turn.play(a))
          }
        }
      }
    }
    return turns

    // return self.flatMap { el in
    //   [[el], self.flatMap { (d) -> [Turn] in
    //     if d == el {
    //       return []
    //     } else {
    //       if case .play(let card) = d, case .play(let elCard) = el {
    //         return ([card, elCard].flatMap {
    //           Turn.play($0)
    //         }).joined()
    //       } else {
    //         return []
    //       }
    //     }
    //    }].joined()
  }
}
