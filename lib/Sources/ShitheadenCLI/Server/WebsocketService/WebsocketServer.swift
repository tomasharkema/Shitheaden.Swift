//
//  WebsocketServer.swift
//
//
//  Created by Tomas Harkema on 18/06/2021.
//

import CustomAlgo
import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import ShitheadenRuntime

actor WebsocketServer {
  let games: AtomicDictionary<String, MultiplayerHandler>

  private var channel: Channel?

  init(games: AtomicDictionary<String, MultiplayerHandler>) {
    self.games = games
  }

  func server(group: MultiThreadedEventLoopGroup) async throws {
    let upgrader = NIOWebSocketServerUpgrader(
      shouldUpgrade: { (channel: Channel, _: HTTPRequestHead) in
        channel.eventLoop.makeSucceededFuture(HTTPHeaders())
      },
      upgradePipelineHandler: { (channel: Channel, _: HTTPRequestHead) in
      channel.pipeline.addHandler( BackPressureHandler()).flatMap {
        channel.pipeline.addHandler(WebSocketServerHandler(games: self.games))
      }
      }
    )

    let bootstrap = ServerBootstrap(group: group)
      // Specify backlog and enable SO_REUSEADDR for the server itself
      .serverChannelOption(ChannelOptions.backlog, value: 256)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

      // Set the handlers that are applied to the accepted Channels
      .childChannelInitializer { channel in
        let httpHandler = HTTPHandler()
        let config: NIOHTTPServerUpgradeConfiguration = (
          upgraders: [upgrader],
          completionHandler: { _ in
            channel.pipeline.removeHandler(httpHandler, promise: nil)
          }
        )
        return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config).flatMap {
          channel.pipeline.addHandler(httpHandler)
        }
      }

      // Enable SO_REUSEADDR for the accepted Channels
      .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

//    defer {
//      try! group.syncShutdownGracefully()
//    }

    let bind = bootstrap.bind(host: "0.0.0.0", port: 3338)

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
  }
}
