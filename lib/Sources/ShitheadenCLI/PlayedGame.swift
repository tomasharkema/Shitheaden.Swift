//
//  PlayedGame.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

import CustomAlgo
import Dispatch
import Foundation
import ShitheadenRuntime
import ShitheadenShared

/*
 struct PlayedGame {
 let scores: [Score]

 func winnigs() -> [String: Int] {
 var playerAndScores = [String: Int]()

 for score in scores {
 let winner = score.winner()

 playerAndScores[winner.0.ai.dynamicType.algoName] = (playerAndScores[winner.0.ai.dynamicType.algoName] ?? 0) + 1
 }

 return playerAndScores
 }

 func winningsFrom() -> [String: [String: Int]] {
 var playerAndScores = [String: [String: Int]]()

 for score in scores {
 let winner = score.winner()
 var arr = [String: Int]()
 for winn in winner.1 {
 arr = playerAndScores[winner.0.ai.dynamicType.algoName] ?? [:]
 arr[winn] = (arr[winn] ?? 0) + 1
 playerAndScores[winner.0.ai.dynamicType.algoName] = arr
 }
 }

 return playerAndScores
 }
 }
 */

struct PlayedGame {
  let games: [GameSnapshot]

  func winnigs() async -> [String: Int] {
    var playerAndScores = [String: Int]()
    let winners: [(GameSnapshot, ObscuredPlayerResult)] =
      await withTaskGroup(of: [(GameSnapshot, ObscuredPlayerResult)].self) { group in
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
    let winners: [(GameSnapshot, [ObscuredPlayerResult], ObscuredPlayerResult, String)] =
      await withTaskGroup(of: [(GameSnapshot, [ObscuredPlayerResult], ObscuredPlayerResult, String)]
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
