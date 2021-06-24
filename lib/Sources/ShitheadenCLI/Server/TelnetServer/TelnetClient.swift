//
//  TelnetClient.swift
//  
//
//  Created by Tomas Harkema on 23/06/2021.
//

import ShitheadenShared
import ShitheadenRuntime
import ANSIEscapeCode
import NIO
import Foundation
import CustomAlgo

class TelnetClient: Client {
  private let context: ChannelHandlerContext
  private let handler: TelnetServerHandler
  let games: AtomicDictionary<String, MultiplayerHandler>
  let quit: EventHandler<Void>.ReadOnly
  let data: EventHandler<ServerRequest>.ReadOnly

  init(context: ChannelHandlerContext, handler: TelnetServerHandler, quit: EventHandler<Void>.ReadOnly, data: EventHandler<String>.ReadOnly,  games: AtomicDictionary<String, MultiplayerHandler>) {
    self.context = context
    self.handler = handler
    self.quit = quit
    self.games = games
    self.data = data.map { input in
      print("DERO: \(input)")

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
    print(choice)

    if choice.hasPrefix("j") {
      // join
      try await joinGame()
    } else if choice.hasPrefix("s") {
      // single
      print(try await singlePlayer())
    } else if choice.hasPrefix("m") {
      // muliplayer
      try await startMultiplayer()
    }

    return try await start()
  }

  private func startMultiplayer() async throws {
    let id = UUID()
    let promise = Promise()
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
    let s = try await data.once()
    print(s)
    guard let code = try await s.getMultiplayerRequest().string?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    else {
      return try await joinGame()
    }

    if let game = await games.get(code) {
      let id = UUID()
      await game.join(id: id, client: self)
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
          //          await context.send(string: string.trimmingCharacters(in: .whitespacesAndNewlines) + "\r\n")
          let _: Void = await withUnsafeContinuation { g in
            self.context.eventLoop.execute {
              let s = string.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: "\n\r") + "\n\r"
              print("WRITE: '\(s)'")
                var buffer = self.context.channel.allocator.buffer(capacity: s.count)
                buffer.writeString(s) //+ "\n\r")

                self.context.writeAndFlush(self.handler.wrapOutboundOut(buffer))
                  .whenComplete {
                    print($0)
                    async {
                      g.resume()
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
          print("START", event)
        case let .error(error: .text(text: text)):
          print("START", event)
        case let .error(error: .gameNotFound(code: code)):
          print("START", event)
        case let .multiplayerEvent(multiplayerEvent: .action(action: action)):

          await send(string: ANSIEscapeCode.Cursor.showCursor + ANSIEscapeCode.Cursor.position(
            row: RenderPosition.input.y + 2,
            column: 0
          ))

        case .quit:
          print("QUIT")
        }
  }


  private func singlePlayer() async throws -> GameSnapshot {
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
          ai: UserInputAIJson(id: id, reader: {
      await self.send(.multiplayerEvent(multiplayerEvent: .action(action: $0)))
      if let error = $1 {
        await self.send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
      }
      return try await self.data.once().getMultiplayerRequest()
    }, renderHandler: {
      _ = await self.send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: $0)))
    })
        ),
      ], slowMode: true
    )

    return try await game.startGame()
  }
}
