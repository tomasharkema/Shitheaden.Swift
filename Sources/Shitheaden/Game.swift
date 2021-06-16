//
//  Game.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//
import Foundation

typealias Table = [Card]

actor Game {
  let shouldPrint: Bool

  init(shouldPrint: Bool, players: [Player]? = nil) {
    self.shouldPrint = shouldPrint
    self.players = players ?? [
      Player(
        handCards: [],
        openTableCards: [],
        closedTableCards: [],
        name: "Zuid (JIJ)",
        turns: [],
        position: .zuid,
        ai: UserInputAI()
      ),
      Player(
        handCards: [],
        openTableCards: [],
        closedTableCards: [],
        name: "West",
        turns: [],
        position: .west,
        ai: RandomBot()
      ),
      Player(
        handCards: [],
        openTableCards: [],
        closedTableCards: [],
        name: "Noord",
        turns: [],
        position: .noord,
        ai: RandomBot()
      ),
      Player(
        handCards: [],
        openTableCards: [],
        closedTableCards: [],
        name: "Oost",
        turns: [],
        position: .oost,
        ai: RandomBot()
      ),
    ]
    CLI.shouldPrintGlbl = shouldPrint
  }

  var deck = Deck(cards: [])
  var players = [Player]()
  var table = Table()
  var burnt = [Card]()

  let rules = Rules.all

  var lastCard: Card? {
    return table.lastCard
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

  func commitTurn(playerIndex: Int, player oldPlayer: Player) async -> Player {
    guard !oldPlayer.done, !done else {
      return oldPlayer
    }

    var player = oldPlayer
    player.sortCards()
    let turn = await player.ai.move(player: player, table: table)

    guard oldPlayer.possibleTurns(table: table).contains(turn) else {
      print(
        "ISSUE!",
        oldPlayer.phase,
        turn,
        oldPlayer.possibleTurns(table: table),
        player.handCards,
        player.openTableCards,
        player.closedTableCards,
        player.hasPutCardsOpen,
        player.done
      )
      print("NO POSSIBLE")
      assertionFailure("This is not possible")
      return await commitTurn(playerIndex: playerIndex, player: oldPlayer)
    }

    // let count = player.turns.filter { $0 == turn }.count
    // if count > 50 {
    //   // bail out when player is in a loop
    //   pass(playerIndex: playerIndex)
    //   return player
    // }

    player.turns.append(turn)

    switch turn {
    case let .play(possibleBeurt):
      let previousTable = table
      table = Array([table + possibleBeurt].joined())

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
        for p in possibleBeurt {
          player.closedTableCards.remove(el: p)
        }

        if let lastTable = previousTable.last, let lastApplied = table.last,
           !lastTable.afters.contains(lastApplied)
        {
          player.handCards.append(contentsOf: table)
          table = []
        }

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
      printState()
      return await commitTurn(playerIndex: playerIndex, player: player)
    }

    if lastCard?.number == .ten {
      burnt += table
      table = []
      printState()
      if rules.contains(.againAfterGoodBehavior), !player.done, !done {
        return await commitTurn(playerIndex: playerIndex, player: player)
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
        return await commitTurn(playerIndex: playerIndex, player: player)
      }
    }

    return player
  }

  var notDonePlayers: [Player] {
    return Array(players.filter { !$0.done })
  }

  var done: Bool {
    notDonePlayers.count == 1
  }

  var winner: Player? {
    done ? players.max { $0.turns.count < $1.turns.count } : nil
  }

  func beurt() async {
    for (index, player) in notDonePlayers.enumerated() {
      players[index] = await commitTurn(playerIndex: index, player: player)
      printState()
    }
    if !done {
      return await beurt()
    }
  }

  func printState(shouldWait: Bool = true) {
    if !shouldPrint {
      return
    }
    CLI.setBackground()
    CLI.clear()
    Position.header >>> "EENENDERTIGEN"
    Position.tafel >>> table.suffix(5).map { $0.description }.joined(separator: " ")

    for player in players {
      if !player.done {
        player.position >>> "\(player.name) \(player.handCards.count) kaarten"
        player.position.down(n: 1) >>> player.latestState
        player.position.down(n: 2) >>> player.showedTable
        player.position.down(n: 3) >>> player.closedTable
      } else {
        player.position >>> "\(player.name) KLAAR"
      }
    }
    if shouldWait {
//      Thread.sleep(forTimeInterval: 0.5)
    }
  }

//  func finishRound() {
//    for loser in pickLosers() {
//      if let index = players.index(of: loser) {
//        players[index].sticks -= 1
//      }
//    }
//  }

  func printEndState() {
    if !shouldPrint {
      return
    }

    CLI.setBackground()
    CLI.clear()
    Position.header >>> "EENENDERTIGEN"
    Position.tafel >>> table.map { $0.description }.joined(separator: " ")

    let losers = pickLosers()

    for player in players {
      if !player.done {
        let extraMessage: String
        if !shouldDoAnotherRound() {
          extraMessage = " WINNAAR!"
        } else if losers.contains(player) {
          extraMessage = " - Klaar"
        } else {
          extraMessage = "\(player.handCards.count) kaarten"
        }
//        } else if player.points == .Verbied || player.points == .AasVerbied {
//          extraMessage = " - Verbied!"
//        }

        player.position >>> "\(player.name)\(extraMessage)"

        player.position.down(n: 1) >>> ""
      } else {
        player.position >>> "\(player.name) KLAAR!"
      }
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

  func startRound() async {
    resetBeurten()

    shuffle()
    deel()
    printState()
    await beurt()

//    finishRound()
    printEndState()
  }

  private func startGameRec(
    restartClosure: (() async -> Bool)?,
    finishClosure: (() async -> Bool)?
  ) async {
    await startRound()

    let restart: () async -> Bool = {
      if self.players[0].done {
        return true
      } else {
        return await restartClosure?() ?? true
      }
    }

    if shouldDoAnotherRound(), await restart() {
      await startGameRec(
        restartClosure: restartClosure,
        finishClosure: finishClosure
      )
    } else {
      if await finishClosure?() ?? false {
        await startGame(
          restartClosure: restartClosure,
          finishClosure: finishClosure
        )
      }
    }
  }

  func startGame(
    restartClosure: (() async -> Bool)? = nil,
    finishClosure: (() async -> Bool)? = nil
  ) async {
    await startGameRec(
      restartClosure: restartClosure,
      finishClosure: finishClosure
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
