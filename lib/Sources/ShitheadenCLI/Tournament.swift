//
//  TestAI.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 31-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

#if os(macOS)

  import CustomAlgo
  import Dispatch
  import Foundation
  import ShitheadenRuntime
  import ShitheadenShared

  class Tournament {
    let roundsPerGame: Int
    let parallelization: Int
    let easer: MaxConcurrentJobs
    let roundEaser: MaxConcurrentJobs

    init(roundsPerGame: Int, parallelization: Int) {
      self.roundsPerGame = roundsPerGame
      self.parallelization = parallelization

      let spawn = max(2, parallelization)
      print("Spawning \(spawn) threads")

      easer = MaxConcurrentJobs(spawn: spawn)
      roundEaser = MaxConcurrentJobs(spawn: spawn)
    }

    func peformanceOfAI(ai: [(GameAi.Type, String)], gameId: String = "0") async -> PlayedGame {
      let playedGames: [GameSnaphot] = await withTaskGroup(of: [GameSnaphot].self) { g in
        for idx in 1 ... roundsPerGame {
          let unlock = await roundEaser.wait()
          if Task.isCancelled {
            return []
          }
          g.async {
            if Task.isCancelled {
              return []
            }
            let players: [Player] = ai.enumerated().map { index, element in
              let (ai, name) = element
              return Player(
                name: name,
                position: Position.allCases[index],
                ai: ai.init()
              )
            }
            let game = Game(
              players: players,
              slowMode: false,
              localUserUUID: nil,
              render: { _, _ in }
            )

            print(" START: \(gameId) \(idx) / \(self.roundsPerGame)")
            let snapshot = await game.startGame()
            print(
              " END: \(gameId) \(idx) / \(self.roundsPerGame) winner: \(snapshot.winner?.algoName ?? "")"
            )
            await unlock()
            return await [game.getSnapshot()]
          }
        }
        return await g.reduce([], +)
      }
      return PlayedGame(games: playedGames)
    }

    func playTournament() async {
      let AIs: [GameAi.Type] = allAlgos + [
        CardRankingAlgo.self, CardRankingAlgoWithUnfairPassing.self,
      ]

      let watch = StopWatch()
      watch.start()

      let stats = await withTaskGroup(of: ([String: Int], [String: [String: Int]])
        .self) { g -> ([String: Int], [String: [String: Int]]) in
        for (index1, ai1) in AIs.enumerated() {
          for (index2, ai2) in AIs.enumerated() {
            for (index3, ai3) in AIs.enumerated() {
              for (index4, ai4) in AIs.enumerated() {
                let unlock = await easer.wait()
                if Task.isCancelled {
                  return ([:], [:])
                }
                g.async {
                  if Task.isCancelled {
                    return ([:], [:])
                  }
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
                  print("UNLOCK!!!!!")
                  await unlock()
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

#endif
