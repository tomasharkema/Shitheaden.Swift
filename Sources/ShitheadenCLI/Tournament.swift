//
//  TestAI.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 31-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import CustomAlgo
import Shitheaden
import ShitheadenShared

struct PlayedGame {
  let games: [Game]

  // spelers.without(el: winner).map { type(of: $0.ai).algoName }

  func winnigs() async -> [String: Int] {
    var playerAndScores = [String: Int]()

    for game in games {
      guard let winner = await game.winner else {
        break
      }

      playerAndScores[String(describing: type(of: winner.ai))] =
        (playerAndScores[String(describing: type(of: winner.ai))] ?? 0) + 1
    }

    return playerAndScores
  }

  func winningsFrom() async -> [String: [String: Int]] {
    var playerAndScores = [String: [String: Int]]()

    for game in games {
      guard let winner = await game.winner else {
        break
      }
      var arr = [String: Int]()
      for winner in await game.players {
        arr = await playerAndScores[winner.ai.algoName] ?? [:]
        await arr[winner.ai.algoName] = (arr[winner.ai.algoName] ?? 0) + 1
        await playerAndScores[winner.ai.algoName] = arr
      }
    }

    return playerAndScores
  }
}

class Tournament {
  let roundsPerGame: Int

  init(roundsPerGame: Int) {
    self.roundsPerGame = roundsPerGame
  }

  func peformanceOfAI(ai: [(GameAi.Type, String)], gameId: String = "0") async -> PlayedGame {


      let playedGames: [Game] = await withTaskGroup(of: [Game].self) { group in
      for idx in 1 ... self.roundsPerGame {
        group.async {
          let players: [Player] = ai.enumerated().map { index, element in
            let (ai, name) = element
            return Player(
              name: name,
              position: Position.allCases[index],
              ai: ai.init()
            )
          }
          let game = Game(players: players)

          await game.startGame(render: { _ in
//            print("STEP", players)
          })
          print("\(gameId) \(idx) winner: \(await game.winner?.ai.algoName ?? "")")
          return [game]
        }
      }

      return await group.reduce([], +)
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
//      g.async {
//        var result = [([String : Int],  [String: [String: Int]] )]()
      for (index1, ai1) in AIs.enumerated() {
        for (index2, ai2) in AIs.enumerated() {
          for (index3, ai3) in AIs.enumerated() {
            for (index4, ai4) in AIs.enumerated() {
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
                let res = await self.peformanceOfAI(ai: ais, gameId: potjeIndex)
                let winnings = await res.winnigs()

                let aisPrint = ais.map {
                  $0.1
                }
                print(
                  "\(potjeIndex) \(winnings) : \(aisPrint)\ntime: \(watch.getLap()) - \(duration.getLap())"
                )
//              result.append(await (winnings, res.winningsFrom()))
                return await (winnings, res.winningsFrom())
              }
            }
          }
        }
//        return g.reduce(([String: Int](), [String: [String: Int]]())) { prev, curr in
//          var new = prev
//
//          for el in curr.0.keys {
//            new.0[el] = curr.0[el]
//          }
//          for el in curr.1.keys {
//            new.1[el] = curr.1[el]
//          }
//          return new
//        }
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
