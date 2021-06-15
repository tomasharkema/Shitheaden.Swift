//
//  Shitheaden.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import CustomAlgo
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
        name: "West (Unfair)",
        position: .west,
        ai: CardRankingAlgoWithUnfairPassing()
      ),
      Player(
        name: "Noord",
        position: .noord,
        ai: CardRankingAlgo()
      ),
      Player(
        name: "Oost",
        position: .oost,
        ai: CardRankingAlgo()
      ),
    ])

    CLI.shouldPrintGlbl = true

    await game.startGame { game in
      CLI.setBackground()
      CLI.clear()
      Position.header.down(n: 1) >>> " Shitheaden"
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
      Thread.sleep(forTimeInterval: 0.1)
    }
  }
}
