//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import CustomAlgo
import Foundation
import Logging
import NIO
import NIOHTTP1
import NIOWebSocket
import ShitheadenRuntime
import ShitheadenShared

class WebsocketClient: Client {
  private let logger = Logger(label: "cli.WebsocketClient")
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
    do {
      await send(.requestSignature)
      guard case let .signature(signature) = try await data.once() else {
        throw NSError(domain: "SIG", code: 0, userInfo: nil)
      }

      logger.info("Received signature: \(signature)")
      logger.info("Fetch local signature")
      guard let url = Bundle.main.url(forResource: "lib", withExtension: "sig") else {
        logger.error("No local signature found in lib.sig")
        throw NSError(domain: "SIG", code: 0, userInfo: nil)
      }

      logger.info("Fetch signature from \(url.absoluteString)")

      let localSignature = try String(contentsOf: url)
        .replacingOccurrences(of: "  -\n", with: "")

      logger.info("Local signature: \(localSignature)")

      if signature == localSignature {
        logger.info("Local signature check succeeded")
        await send(.signatureCheck(true))
      } else {
        throw NSError(domain: "SIG", code: 0, userInfo: nil)
      }

    } catch {
      logger.error("Local signature not succeeded")
      await send(.signatureCheck(false))
    }

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
        return try await startSinglePlayer(contestants: 3)

      case .quit:
        logger.error("GOT QUIT!!!!")
      case .startGame:
        logger.info("startGame!")
      case .signature:
        break

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

  private func startSinglePlayer(contestants: Int) async throws {
    let id = UUID()

    let game = Game(
      contestants: contestants,
      ai: CardRankingAlgoWithUnfairPassing.self,
      localPlayer: Player(
        id: id,
        name: "Zuid (JIJ)",
        position: .zuid,
        ai: UserInputAIJson(id: id, reader: { _, error in
          if let error = error {
            await self
              .send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
          }
          return try await self.data.once().getMultiplayerRequest()
        }, renderHandler: {
          await self
            .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: $0)))
        })
      ),
      slowMode: true
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
    let _: Void = await withUnsafeContinuation { cont in
      self.context.eventLoop.execute {
        // We can't really check for error here, but it's also not the purpose of the
        // example so let's not worry about it.
        do {
          let data = try JSONEncoder().encode(event)

          var buffer = self.context.channel.allocator.buffer(capacity: data.count)
          buffer.writeBytes(data)

          let frame = WebSocketFrame(fin: true, opcode: .binary, data: buffer)
          self.context.writeAndFlush(self.handler.wrapOutboundOut(frame)).whenComplete { _ in
            asyncDetached {
              cont.resume()
            }
          }
        } catch {
          self.logger.error("\(error)")
        }
      }
    }
  }
}
