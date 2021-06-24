//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import CustomAlgo
import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import ShitheadenRuntime
import ShitheadenShared

class WebsocketClient: Client {
  private let context: ChannelHandlerContext
  let handler: WebSocketServerHandler
  let games: AtomicDictionary<String, MultiplayerHandler>

  let quit: EventHandler<Void>.ReadOnly
  let data: EventHandler<ServerRequest>.ReadOnly

  init(
    context: ChannelHandlerContext,
    handler: WebSocketServerHandler,
    quit: EventHandler<Void>,
    data: EventHandler<ServerRequest>,
    games: AtomicDictionary<String, MultiplayerHandler>
  ) {
    self.context = context
    self.handler = handler
    self.quit = quit.readOnly
    self.data = data.readOnly
    self.games = games

    data.on {
      if case .quit = $0 {
        quit.emit(())
      }
    }
  }

  func start() async {
    await send(.requestMultiplayerChoice)

    do {
      let choice: ServerRequest? = try await data.once()
      switch choice {
      case let .joinMultiplayer(code):
        try await joinGame(code: code)
      case .startMultiplayer:
        try await startMultiplayer()

      case .multiplayerRequest:
        return await start()

      case .singlePlayer:
        return try await startSinglePlayer()

      case .quit:
        print("GOT QUIT!!!!")
      case .startGame:
        print("OJOO!")

      case .none:
        return await start()
      }
    } catch {
      return await start()
    }
  }

  private func joinGame(code: String) async throws {
    if let game = await games.get(code) {
      let id = UUID()
      await game.join(id: id, client: self)
      try await game.finished()
    } else {
      await send(.error(error: .gameNotFound(code: code)))
      return await start()
    }
  }

  private func startSinglePlayer() async throws {
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
          ai: UserInputAIJson(id: id, reader: { _, error in
            if let error = error {
              await self.send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
            }
            return try await self.data.once().getMultiplayerRequest()
          }, renderHandler: {
            await self.send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: $0)))
            //            if let error = $1 {
            //              await self.send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
            //            }
          })
        ),
      ], slowMode: true
    )

    try await game.startGame()
  }

  private func startMultiplayer() async throws {
    let id = UUID()
    let pair = MultiplayerHandler(challenger: (id, self))
    await games.insert(pair.code, value: pair)

    try await pair.waitForStart()
  }

  func send(_ event: ServerEvent) async {
    return await withUnsafeContinuation { g in
      self.context.eventLoop.execute {
        // We can't really check for error here, but it's also not the purpose of the
        // example so let's not worry about it.
        do {
          let data = try JSONEncoder().encode(event)

          var buffer = self.context.channel.allocator.buffer(capacity: data.count)
          buffer.writeBytes(data)

          let frame = WebSocketFrame(fin: true, opcode: .binary, data: buffer)
          self.context.writeAndFlush(self.handler.wrapOutboundOut(frame)).whenComplete {
            print($0)
            asyncDetached {
              g.resume()
            }
          }
        } catch {
          print(error)
        }
      }
    }
  }
}
