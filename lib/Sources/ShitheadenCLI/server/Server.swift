//
//  WebSocketTimeHandler.swift
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

actor Server {
  func server() throws {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    let upgrader = NIOWebSocketServerUpgrader(
      shouldUpgrade: { (channel: Channel, _: HTTPRequestHead) in
        channel.eventLoop.makeSucceededFuture(HTTPHeaders())
      },
      upgradePipelineHandler: { (channel: Channel, _: HTTPRequestHead) in
        channel.pipeline.addHandler(WebSocketTimeHandler())
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

    defer {
      try! group.syncShutdownGracefully()
    }

    let channel = try bootstrap.bind(host: "0.0.0.0", port: 3338).wait()

    guard let localAddress = channel.localAddress else {
      fatalError(
        "Address was unable to bind. Please check that the socket was not closed or that the address family was understood."
      )
    }
    print("Server started and listening on \(localAddress)")

    // This will never unblock as we don't close the ServerChannel
    try channel.closeFuture.wait()

    print("Server closed")
  }
}
