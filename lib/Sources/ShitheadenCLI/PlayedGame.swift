//
//  PlayedGame.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

#if os(macOS)

import CustomAlgo
import Dispatch
import Foundation
import ShitheadenRuntime
import ShitheadenShared

class PlayedGame {
  let games: [GameSnapshot]

  init(games: [GameSnapshot]) {
    self.games = games
  }

  func winnigs() async -> [String: Int] {
    var playerAndScores = [String: Int]()
    let winners: [(GameSnapshot, TurnRequest)] =
      await withTaskGroup(of: [(GameSnapshot, TurnRequest)].self) { group in
        for game in games {
          group.async(priority: .background) {
            if let winner = game.winner {
              return [(game, winner)]
            } else {
              return []
            }
          }
        }
        return await group.reduce([], +)
      }

    for winner in winners {
      playerAndScores[winner.1.algoName] = (playerAndScores[winner.1.algoName] ?? 0) + 1
    }

    return playerAndScores
  }

  func winningsFrom() async -> [String: [String: Int]] {
    let winners: [(GameSnapshot, [TurnRequest], TurnRequest, String)] =
      await withTaskGroup(of: [(GameSnapshot, [TurnRequest], TurnRequest, String)]
        .self) { group in
        for game in games {
          group.async(priority: .background) {
            if let winner = game.winner {
              return [(game, game.players, winner, winner.algoName)]
            } else {
              return []
            }
          }
        }
        return await group.reduce([], +)
      }

    var playerAndScores = [String: [String: Int]]()

    for (_, players, _, _) in winners {
      for winner in players {
        var arr = [String: Int]()
        arr = playerAndScores[winner.algoName] ?? [:]
        arr[winner.algoName] = (arr[winner.algoName] ?? 0) + 1
        playerAndScores[winner.algoName] = arr
      }
    }

    return playerAndScores
  }
}

#endif
