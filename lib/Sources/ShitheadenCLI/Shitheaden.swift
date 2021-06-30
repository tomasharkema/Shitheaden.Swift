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
import Logging
import ShitheadenCLIRenderer
import ShitheadenRuntime

private let logger = Logger(label: "cli")

@main
struct Shitheaden: ParsableCommand {
  @Flag(help: "Test all the AI's")
  var testAi = false

  @Option(name: .shortAndLong, help: "The number of parallelization")
  var parallelization: Int = 8

  @Option(name: .shortAndLong, help: "The number of rounds")
  var rounds: Int = 10

  mutating func run() async throws {
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
      let _: Void = await withUnsafeContinuation { cont in
        DispatchQueue.global().async {
          async {
            await Tournament(roundsPerGame: rounds, parallelization: parallelization)
              .playTournament()
            cont.resume()
          }
        }
      }
    }
  #endif

  private func interactive() async {
    LoggingSystem.bootstrap { _ in NoopLogger() }
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
            // swiftlint:disable:next disable_print
            print($0) // print to stout
          }, read: {
            await Keyboard.getKeyboardInput()
          })
        ),
      ],
      slowMode: true
    )
    do {
      try await game.startGame()
    } catch {
      logger.error("\(error)")
    }
  }
}

// swiftlint:disable disable_print

extension UserInputAIJson {
  static func cli(
    id: UUID,
    print: @escaping (String) async -> Void,
    read: @escaping () async -> String
  ) -> UserInputAIJson {
    UserInputAIJson(id: id, reader: { _, error in

      await print(ANSIEscapeCode.Cursor.showCursor + ANSIEscapeCode.Cursor.position(
        row: RenderPosition.input.yAxis + 1,
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
