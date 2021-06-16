//
//  TestAI.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 31-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import CustomAlgo
import Dispatch
import ShitheadenRuntime
import ShitheadenShared

struct PlayedGame {
  let games: [Game]

  func winnigs() async -> [String: Int] {
    var playerAndScores = [String: Int]()
    let winners: [(Game, Player)] = await withTaskGroup(of: [(Game, Player)].self) { group in
      for game in games {
        group.async(priority: .background) {
          await [(game, game.winner!)]
        }
      }
      return await group.reduce([], +)
    }

    for winner in winners {
      playerAndScores[String(describing: type(of: winner.1.ai))] =
        (playerAndScores[String(describing: type(of: winner.1.ai))] ?? 0) + 1
    }

    return playerAndScores
  }

  func winningsFrom() async -> [String: [String: Int]] {
    let winners: [(Game, [Player], Player, GameAi)] =
      await withTaskGroup(of: [(Game, [Player], Player, GameAi)].self) { group in
        for game in games {
          group.async(priority: .background) {
            await [(game, game.players, game.winner!, game.winner!.ai)]
          }
        }
        return await group.reduce([], +)
      }

    var playerAndScores = [String: [String: Int]]()

    for (game, players, winner, _) in winners {
      for winner in players {
        var arr = [String: Int]()
        arr = playerAndScores[winner.ai.algoName] ?? [:]
        arr[winner.ai.algoName] = (arr[winner.ai.algoName] ?? 0) + 1
        playerAndScores[winner.ai.algoName] = arr
      }
    }

    return playerAndScores
  }
}

class Tournament {
  let roundsPerGame: Int
  let parallelization: Int

  init(roundsPerGame: Int, parallelization: Int) {
    self.roundsPerGame = roundsPerGame
    self.parallelization = parallelization
  }

  func peformanceOfAI(ai: [(GameAi.Type, String)], gameId: String = "0") async -> PlayedGame {
    var playedGames = [Game]()

    for idx in 1 ... roundsPerGame {
      let players: [Player] = ai.enumerated().map { index, element in
        let (ai, name) = element
        return Player(
          name: name,
          position: Position.allCases[index],
          ai: ai.init()
        )
      }
      let game = Game(players: players, render: { _, _ in })

      print(" START: \(gameId) \(idx) / \(roundsPerGame)")
      await game.startGame()
      print(
        " END: \(gameId) \(idx) / \(roundsPerGame) winner: \(await game.winner?.ai.algoName ?? "")"
      )

      playedGames.append(game)
    }

    return PlayedGame(games: playedGames)
  }

  func playTournament() async {
    let AIs: [GameAi.Type] = allAlgos + [
      CardRankingAlgo.self, CardRankingAlgoWithUnfairPassing.self,
    ]

    let watch = StopWatch()
    watch.start()

    let semaphore = DispatchSemaphore(value: parallelization)

    let stats = await withTaskGroup(of: ([String: Int], [String: [String: Int]])
      .self) { g -> ([String: Int], [String: [String: Int]]) in
//      g.async {
//        var result = [([String : Int],  [String: [String: Int]] )]()
      for (index1, ai1) in AIs.enumerated() {
        for (index2, ai2) in AIs.enumerated() {
          for (index3, ai3) in AIs.enumerated() {
            for (index4, ai4) in AIs.enumerated() {
              semaphore.wait()
              g.async {
                let potjeIndex: String = [index1, index2, index3, index4].map { "\($0)" }
                  .joined(separator: ",")
                let duration = StopWatch()
                duration.start()
                let ais = [
                  (ai1, "\(ai1.algoName) 1"),
                  (ai2, "\(ai2.algoName) 2"),
                  (ai3, "\(ai3.algoName) 3"),
                  (ai4, "\(ai4.algoName) 4"),
                ]

                print(
                  "START: \(index1 + index2 + index3 + index4) / \(AIs.count * 4) / \(self.roundsPerGame)"
                )
                let res = await self.peformanceOfAI(ai: ais, gameId: potjeIndex)
                print(
                  "END: \(index1 + index2 + index3 + index4) / \(AIs.count * 4) / \(self.roundsPerGame)"
                )

                let winnings = await res.winnigs()

                let aisPrint = ais.map {
                  $0.1
                }
                print(
                  "\(potjeIndex) \(winnings) : \(aisPrint)\ntime: \(watch.getLap()) - \(duration.getLap())"
                )
                semaphore.signal()
                return await (winnings, res.winningsFrom())
              }
            }
          }
        }
      }

      return await g.reduce(([String: Int](), [String: [String: Int]]())) { prev, curr in
        var new = prev

        for el in curr.0.keys {
          new.0[el] = curr.0[el]
        }
        for el in curr.1.keys {
          new.1[el] = curr.1[el]
        }
        return new
      }
    }

    let scores = stats.0.sorted { lhs, rhs in
      lhs.1 > rhs.1
    }

    print("\n\nSCORES: (potjes van \(roundsPerGame) gewonnen)\n")

    scores.reduce("") { prev, el in
      prev + "\(el.0): \(el.1)\n"
    }.print()

    // winnings from
    print(stats.1.reduce("Performance:\n") { prev, el in

      let ranks = el.1.sorted { l, r in
        l.1 > r.1
      }.reduce("") { prev, el in
        prev + "     \(el.0): \(el.1)\n"
      }

      return prev + "\(el.0): wint van\n\(ranks)\n"
    })

    print("Tijd: \(watch.getLap())\n")
  }
}
