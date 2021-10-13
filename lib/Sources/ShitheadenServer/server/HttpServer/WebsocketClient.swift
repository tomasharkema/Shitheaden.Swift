//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import CustomAlgo
import Foundation
import Logging
import ShitheadenCLIRenderer
import ShitheadenRuntime
import ShitheadenShared
import Vapor

class WebsocketClient: Client {
  private let logger = Logger(label: "cli.WebsocketClient")
  private let websocket: WebSocket
  let games: AtomicDictionary<String, MultiplayerHandler>

  let onQuit = EventHandler<UUID>()
  let onData = EventHandler<ServerRequest>()

  var quit: EventHandler<UUID>.ReadOnly { onQuit.readOnly }
  var data: EventHandler<ServerRequest>.ReadOnly { onData.readOnly }

  init(
    websocket: WebSocket,
    games: AtomicDictionary<String, MultiplayerHandler>
  ) {
    self.websocket = websocket
    self.games = games

    websocket.onBinary {
      do {
        var buffer = $1
        guard let data = buffer
          .readBytes(length: buffer.readableBytes)
        else {
          throw NSError(domain: "", code: 0, userInfo: nil)
        }
        let serverRequest = try JSONDecoder().decode(ServerRequest.self, from: Data(data))
        self.onData.emit(serverRequest)
      } catch {
        self.logger.error("Error: \(error)")
      }
    }

    websocket.onText {
      do {
        let serverRequest = try JSONDecoder()
          .decode(ServerRequest.self, from: $1.data(using: .utf8)!)
        self.onData.emit(serverRequest)
      } catch {
        self.logger.error("Error: \(error)")
      }
    }
  }

  func start() async throws {
    do {
      try await send(.requestSignature)
      guard case let .signature(signature) = try await data.once() else {
        throw NSError(domain: "SIG", code: 0, userInfo: nil)
      }

      logger.info("Received signature: \(signature)")
      logger.info("Fetch local signature")
      let localSignature = await try Signature.getSignature()

      logger.info("Local signature: \(localSignature)")

      if signature == localSignature {
        logger.info("Local signature check succeeded")
        try await send(.signatureCheck(true))
      } else {
        throw NSError(domain: "SIG", code: 0, userInfo: nil)
      }

    } catch {
      logger.error("Local signature not succeeded")
      try await send(.signatureCheck(false))
    }

    try await send(.requestMultiplayerChoice)

    do {
      let choice: ServerRequest? = try await data.once()
      switch choice {
      case let .joinMultiplayer(name, code):
        try await joinGame(name: name, code: code)

      case let .startMultiplayer(name):
        try await startMultiplayer(name: name)

      case .multiplayerRequest:
        return try await start()

      case .singlePlayer:
        return try await startSinglePlayer(contestants: 3)

      case .quit:
        logger.error("GOT QUIT!!!!")
      case .startGame:
        logger.info("startGame!")
      case .signature:
        break

      case .none:
        return try await start()
      }
    } catch {
      logger.error("Error: \(error)")
      return try await start()
    }
  }

  private func joinGame(name: String, code: String) async throws {
    if let game = await games.get(code) {
      let id = UUID()
      try await game
        .join(competitor: Contestant(uuid: id, name: name, client: self)) // (id: id, client: self)
      try await game.finished()
    } else {
      try await send(.error(error: .gameNotFound(code: code)))
      return try await start()
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
            try await self
              .send(.multiplayerEvent(multiplayerEvent: .error(error: error)))
          }
          return try await self.data.once(initial: false).getMultiplayerRequest()
        }, renderHandler: {
          try await self
            .send(.multiplayerEvent(multiplayerEvent: .gameSnapshot(snapshot: $0)))
        })
      ),
      rules: Rules.all,
      slowMode: true
    )
    let snapshot = try await game.startGame()
    asyncDetached(priority: .background) {
      try await WriteSnapshotToDisk.write(snapshot: snapshot)
    }
  }

  private func startMultiplayer(name: String) async throws {
    let id = UUID()
    let pair = MultiplayerHandler(challenger: Contestant(uuid: id, name: name, client: self))
    await games.insert(pair.code, value: pair)

    try await pair.createGame()
  }

  func send(_ event: ServerEvent) async throws {
    let _: Void = try await withUnsafeThrowingContinuation { cont in
      do {
        let data = try JSONEncoder().encode(event)

        let promise: EventLoopPromise<Void> = websocket.eventLoop.makePromise()
        websocket.send(Array(data), promise: promise)

        promise.futureResult.whenSuccess {
          cont.resume()
        }
        promise.futureResult.whenFailure {
          cont.resume(throwing: $0)
        }
      } catch {
        self.logger.error("\(error)")
      }
    }
  }
}
