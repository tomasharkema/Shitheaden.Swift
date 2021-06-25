//
//  Shitheaden.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import ANSIEscapeCode
import ArgumentParser
import CustomAlgo
import Foundation
import NIO
import ShitheadenRuntime
import Logging

private let logger = Logger(label: "cli")

@main
struct Shitheaden: ParsableCommand {

    @Flag(help: "Test all the AI's")
    var testAi = false

  @Flag(help: "Start a server")
  var server = false

  @Option(name: .shortAndLong, help: "The number of parallelization")
  var parallelization: Int = 8

  @Option(name: .shortAndLong, help: "The number of rounds")
  var rounds: Int = 10

  mutating func run() async throws {
    logger.notice("START! \(server)")
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
#if os(Linux)
    await startServer()
    return
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
    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount / 2)
    let games = AtomicDictionary<String, MultiplayerHandler>()
    async {
      do {
        logger.notice("START! websocket")
        let server = WebsocketServer(games: games)
        let channel = try await server.server(group: group)
        try channel.closeFuture.wait()
      } catch {
        logger.error("\(error)")
      }
    }
    async {
      let server = TelnetServer(games: games)
      let channel = try await server.start(group: group)
      try channel.closeFuture.wait()
    }
    async {
      let server = SSHServer(games: games)
      let channel = try await server.start(group: group)
      try channel.closeFuture.wait()
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
          ai: UserInputAIJson.cli(id: id, print: {
            print($0) // print to stout
          }, read: {
            await Keyboard.getKeyboardInput()
          })
        ),
      ], slowMode: true
    )
    do {
      try await game.startGame()
    } catch {
      logger.error("\(error)")
    }
  }
}

extension UserInputAIJson {
  static func cli(
    id: UUID,
    print: @escaping (String) async -> Void,
    read: @escaping () async -> String
  ) -> UserInputAIJson {
    return UserInputAIJson(id: id, reader: { _, error in
      await print(ANSIEscapeCode.Cursor.showCursor + ANSIEscapeCode.Cursor.position(
        row: RenderPosition.input.y + 1,
        column: 0
      ))
      if let error = error {
        await print(Renderer.error(error: error))
      }
      let input = await read()
      await print(ANSIEscapeCode.Cursor.hideCursor)
      let inputs = input.split(separator: ",").map {
        Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
      }
      if inputs.contains(nil) {
        return .string(input)
      }

      return .cardIndexes(inputs.map { $0! })
    }, renderHandler: { game in
      await print(Renderer.render(game: game))
    })
  }
}
