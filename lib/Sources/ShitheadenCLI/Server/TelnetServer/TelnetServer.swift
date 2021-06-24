//
//  TelnetServer.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

import ANSIEscapeCode
import CustomAlgo
import Foundation
import ShitheadenRuntime
import ShitheadenShared
import NIO

class TelnetServer {
  let games: AtomicDictionary<String, MultiplayerHandler>
  private var channel: Channel?

  init(games: AtomicDictionary<String, MultiplayerHandler>) {
    self.games = games
  }

  func start(group: MultiThreadedEventLoopGroup) async throws -> Channel {
    let bootstrap = ServerBootstrap(group: group)
      .serverChannelOption(ChannelOptions.backlog, value: 256)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .childChannelInitializer { channel in
        channel.pipeline.addHandler( BackPressureHandler()).flatMap {
          channel.pipeline.addHandler(TelnetServerHandler(games: self.games))
        }
      }

    let bind = bootstrap.bind(host: "0.0.0.0", port: 3333)

    let channel: Channel = try await withUnsafeThrowingContinuation { g in
      bind.whenSuccess {
        g.resume(returning: $0)
      }
      bind.whenFailure {
        g.resume(throwing: $0)
      }
    }

    guard let localAddress = channel.localAddress else {
      fatalError(
        "Address was unable to bind. Please check that the socket was not closed or that the address family was understood."
      )
    }
    print("Server started and listening on \(localAddress)")
    self.channel = channel
    return channel
  }
}

