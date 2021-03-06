//
//  TelnetServer.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

import ANSIEscapeCode
import CustomAlgo
import Foundation
import Logging
import NIO
import NIOExtras
import ShitheadenRuntime
import ShitheadenShared
import AsyncAwaitHelpers

class TelnetServer {
  private let logger = Logger(label: "cli.TelnetServer")
  let games: DictionaryActor<String, MultiplayerHandler>
  private var channel: Channel?

  init(games: DictionaryActor<String, MultiplayerHandler>) {
    self.games = games
  }

  func start(
    quiesce: ServerQuiescingHelper,
    group: MultiThreadedEventLoopGroup
  ) async throws -> Channel {
    let bootstrap = ServerBootstrap(group: group)
      .serverChannelOption(ChannelOptions.backlog, value: 256)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .serverChannelInitializer { channel in
        channel.pipeline.addHandler(quiesce.makeServerChannelHandler(channel: channel))
      }
      .childChannelInitializer { channel in
        channel.pipeline.addHandler(BackPressureHandler()).flatMap {
          channel.pipeline.addHandler(TelnetServerHandler(games: self.games))
        }
      }

    let bind = bootstrap.bind(host: "0.0.0.0", port: 3333)

    let channel: Channel = try await bind.get()

    guard let localAddress = channel.localAddress else {
      fatalError(
        "Address was unable to bind. Please check that the socket was not closed or that the address family was understood."
      )
    }
    logger.info("Server started and listening on \(localAddress)")
    self.channel = channel
    return channel
  }
}

extension EventLoopFuture {
  func get() async throws -> Value {
    try await withCheckedThrowingContinuation { cont in
      whenSuccess {
        cont.resume(returning: $0)
      }
      whenFailure {
        cont.resume(throwing: $0)
      }
    }
  }
}
