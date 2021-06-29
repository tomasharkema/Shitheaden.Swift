//
//  TelnetClient.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import ANSIEscapeCode
import CustomAlgo
import Foundation
import Logging
import NIO
import ShitheadenCLIRenderer
import ShitheadenRuntime
import ShitheadenShared

class TelnetClient: Client {
  private let logger = Logger(label: "cli.TelnetClient")
  private let context: ChannelHandlerContext
  private let handler: TelnetServerHandler
  let games: AtomicDictionary<String, MultiplayerHandler>
  let quit: EventHandler<Void>.ReadOnly
  let data: EventHandler<ServerRequest>.ReadOnly

  init(
    context: ChannelHandlerContext,
    handler: TelnetServerHandler,
    quit: EventHandler<Void>.ReadOnly,
    data: EventHandler<String>.ReadOnly,
    games: AtomicDictionary<String, MultiplayerHandler>
  ) {
    self.context = context
    self.handler = handler
    self.quit = quit
    self.games = games
    self.data = data.map { input in
      if input.contains("quit") {
        return .quit
      }
      let inputs = input.split(separator: ",").map {
        Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
      }
      if inputs.contains(nil) {
        return .multiplayerRequest(.string(input))
      }

      return .multiplayerRequest(.cardIndexes(inputs.map { $0! }))
    }
  }

  func start() async throws {
    await send(string: """
    Welkom bij shitheaden!!

    Typ het volgende om te beginnen:
    join          Join een online game
    single        Start een single game
    multiplayer   Start een multiplayer game
    """)
    guard let choice: String = try await data.once().getMultiplayerRequest().string
    else {
      return try await start()
    }

    if choice.hasPrefix("j") {
      // join
      try await joinGame()
    } else if choice.hasPrefix("s") {
      // single
      let single = try await singlePlayer(contestants: 3)
      logger.info("single game \(single)")
    } else if choice.hasPrefix("m") {
      // muliplayer
      try await startMultiplayer()
    }

    return try await start()
  }

  private func startMultiplayer() async throws {
    let id = UUID()
    let pair = MultiplayerHandler(
      challenger: (id, self)
    )
    await games.insert(pair.code, value: pair)

    try await pair.waitForStart()
  }

  private func joinGame() async throws {
    await send(string: """


        Typ je code in:
    """)
    let event = try await data.once()

    guard let code = try await event.getMultiplayerRequest().string?
      .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    else {
      return try await joinGame()
    }

    if let game = await games.get(code) {
      let id = UUID()
      try await game.join(id: id, client: self)
      try await game.finished()
      return try await start()
    } else {
      await send(string: """

            Game niet gevonden...
      """)
      return try await start()
    }
  }

  func send(string: String) async {
    await send(.multiplayerEvent(multiplayerEvent: .string(string: string)))
  }

  func send(_ event: ServerEvent) async {
    switch event {
    case let .multiplayerEvent(.string(string)):
      let _: Void = await withUnsafeContinuation { cont in
        self.context.eventLoop.execute {
          let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "\n\r") + "\n\r"

          var buffer = self.context.channel.allocator.buffer(capacity: trimmedString.count)
          buffer.writeString(trimmedString)

          self.context.writeAndFlush(self.handler.wrapOutboundOut(buffer))
            .whenComplete { _ in
              async {
                cont.resume()
              }
            }
        }
      }

    case let .multiplayerEvent(.error(error)):
      await send(string: await Renderer.error(error: error))

    case let .multiplayerEvent(.gameSnapshot(snapshot)):
      await send(string: await Renderer.render(game: snapshot))

    case .waiting:
      await send(string: """

      Joined! Wachten tot de game begint...
      """)
    case let .joined(numberOfPlayers):
      await send(string: """

      Aantal spelers: \(numberOfPlayers)
      """)
    case let .codeCreate(code):
      await send(string: """

      Hier is je code: \(code). Geef deze code aan je vrienden en wacht tot ze joinen!
      Als je klaar bent, typ start!
      """)

    case .start:
      await send(string: """


      Start game!
      """)
    case let .error(.playerError(error)):
      await send(string: await Renderer.error(error: error))

    case .requestMultiplayerChoice:
      logger.info("START \(event)")
    case let .error(error: .text(text: text)):
      logger.info("START \(event)")
    case let .error(error: .gameNotFound(code: code)):
      logger.info("START, \(event)")
    case let .multiplayerEvent(multiplayerEvent: .action(action: action)):

      await send(string: ANSIEscapeCode.Cursor.showCursor + ANSIEscapeCode.Cursor.position(
        row: RenderPosition.input.yAxis + 2,
        column: 0
      ))

    case .quit:
      logger.info("quit")
    case .requestSignature, .signatureCheck:
      break
    }
  }

  private func singlePlayer(contestants: Int) async throws -> GameSnapshot {
    let identifier = UUID()

    let game = Game(
      contestants: contestants,
      ai: CardRankingAlgoWithUnfairPassing.self,
      localPlayer: Player(
        id: identifier,
        name: "Zuid (JIJ)",
        position: .zuid,
        ai: UserInputAIJson(id: identifier, reader: {
          await self.send(.multiplayerEvent(multiplayerEvent: .action(action: $0)))
          if let error = $1 {
            await self
              .send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
          }
          return try await self.data.once().getMultiplayerRequest()
        }, renderHandler: {
          _ = await self
            .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: $0)))
        })
      ),
      slowMode: true, endGameHandler: { snapshot in
        async {
          try await WriteSnapshotToDisk.write(snapshot: snapshot)
        }
      }
    )

    return try await game.startGame()
  }
}
