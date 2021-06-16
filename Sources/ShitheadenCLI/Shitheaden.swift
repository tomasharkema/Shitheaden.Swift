//
//  Shitheaden.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Foundation
import Shitheaden

@main
enum Shitheaden {

  static func main() async {
    let args = CommandLine.arguments

    var tournament = false

    if args.count > 1 {
      let arg = args[1]

      if arg == "test-ai" {
        tournament = true
      }
    }

    if tournament {
      await playTournament()
    } else {
      await interactive()
    }
  }


  private static func playTournament() async {
    CLI.shouldPrintGlbl = false
    await Tournament(roundsPerGame: 10).playTournament()
  }

  private static func interactive() async {
    let game = Game(players: [
      Player(
        name: "Zuid (JIJ)",
        position: .zuid,
        ai: UserInputAI()
      ),
      Player(
        name: "West",
        position: .west,
        ai: RandomBot()
      ),
      Player(
        name: "Noord",
        position: .noord,
        ai: RandomBot()
      ),
      Player(
        name: "Oost",
        position: .oost,
        ai: RandomBot()
      ),
    ]
    )
    
    CLI.shouldPrintGlbl = true

    await game.startGame { game in
      CLI.setBackground()
      CLI.clear()
      Position.header >>> "EENENDERTIGEN"
      await Position.tafel >>> game.table.suffix(5).map { $0.description }.joined(separator: " ")

      for player in await game.players {
        if await !player.done {
          player.position >>> "\(player.name) \(player.handCards.count) kaarten"
          player.position.down(n: 1) >>> player.latestState
          player.position.down(n: 2) >>> player.showedTable
          player.position.down(n: 3) >>> player.closedTable
        } else {
          player.position >>> "\(player.name) KLAAR"
        }
      }
      Thread.sleep(forTimeInterval: 1)
    }
  }
}

extension Game {

  //  func finishRound() {
  //    for loser in pickLosers() {
  //      if let index = players.index(of: loser) {
  //        players[index].sticks -= 1
  //      }
  //    }
  //  }
//
//  func printEndState() {
//    CLI.setBackground()
//    CLI.clear()
//    Position.header >>> "EENENDERTIGEN"
//    Position.tafel >>> table.map { $0.description }.joined(separator: " ")
//
//    let losers = pickLosers()
//
//    for player in players {
//      if !player.done {
//        let extraMessage: String
//        if !shouldDoAnotherRound() {
//          extraMessage = " WINNAAR!"
//        } else if losers.contains(player) {
//          extraMessage = " - Klaar"
//        } else {
//          extraMessage = "\(player.handCards.count) kaarten"
//        }
//        //        } else if player.points == .Verbied || player.points == .AasVerbied {
//        //          extraMessage = " - Verbied!"
//        //        }
//
//        player.position >>> "\(player.name)\(extraMessage)"
//
//        player.position.down(n: 1) >>> ""
//      } else {
//        player.position >>> "\(player.name) KLAAR!"
//      }
//    }
//  }
}
