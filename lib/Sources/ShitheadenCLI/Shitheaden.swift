//
//  Shitheaden.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import ArgumentParser
import CustomAlgo
import Foundation
import ShitheadenRuntime

@main
struct Shitheaden: ParsableCommand {
  #if os(macOS)
    @Flag(help: "Test all the AI's")
    var testAi = false
  #endif

  @Flag(help: "Start a server")
  var server = false

  @Option(name: .shortAndLong, help: "The number of parallelization")
  var parallelization: Int = 8

  @Option(name: .shortAndLong, help: "The number of rounds")
  var rounds: Int = 10

  mutating func run() async throws {
    #if os(Linux)
      await startServer()
      return
    #endif

    print("START! \(server)")
    if server {
      await startServer()
      return
    }
    #if os(macOS)
      if testAi {
        await playTournament()
        return
      }
    #endif
    await interactive()
  }

  #if os(macOS)
    private func playTournament() async {
      return await withUnsafeContinuation { d in
        DispatchQueue.global().async {
          async {
            await Tournament(roundsPerGame: rounds, parallelization: parallelization)
              .playTournament()
            d.resume()
          }
        }
      }
    }
  #endif

  private func startServer() async {
    async {
      do {
        print("START! websocket")
        let server = Server()
        try await server.server()
      } catch {
        print(error)
      }
    }
    async {
      let server = TelnetServer()
      await server.startServer()
    }
    return await withUnsafeContinuation { _ in }
  }

  private func interactive() async {
    let id = UUID()
    let game = Game(
      players: [
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
        Player(
          id: id,
          name: "Zuid (JIJ)",
          position: .zuid,
          ai: UserInputAI(id: id)
        ),
      ], slowMode: true
//      , localUserUUID: id, render: { game, clear in
//        await print(Renderer.render(game: game, clear: clear))
//      }
    )

    await game.startGame()
  }
}

actor AtomicBool {
  var value: Bool

  init(value: Bool) {
    self.value = value
  }

  func set(value: Bool) {
    self.value = value
  }
}
