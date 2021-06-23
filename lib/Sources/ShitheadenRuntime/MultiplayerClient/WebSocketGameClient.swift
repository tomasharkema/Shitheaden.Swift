//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import ShitheadenShared

public class WebSocketGameClient {
  private let address = "192.168.1.102"
//    private let address = "192.168.1.76"

  public init() {}

  public func start() async throws -> WebSocketClient {
    let handler = WebSocketHandler()
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let bootstrap = ClientBootstrap(group: group)
      .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
      .channelInitializer { channel in
        let httpHandler = HTTPInitialRequestHandler()

        let websocketUpgrader = NIOWebClientSocketUpgrader(
          requestKey: "OfS0wDaT5NoxF2gqm7Zj2YtetzM=",
          upgradePipelineHandler: { (
            channel: Channel,
            _: HTTPResponseHead
          ) in
            channel.pipeline
              .addHandler(handler)
          }
        )

        let config: NIOHTTPClientUpgradeConfiguration = (
          upgraders: [websocketUpgrader],
          completionHandler: { _ in
            channel.pipeline.removeHandler(httpHandler, promise: nil)
          }
        )

        return channel.pipeline.addHTTPClientHandlers(withClientUpgrade: config).flatMap {
          channel.pipeline.addHandler(httpHandler)
        }
      }

    //      let channel = try bootstrap.connect(host: "shitheaden-api.harkema.io", port: 443).wait()
    async let context = handler.context.once()
    let _: Channel = try await withUnsafeThrowingContinuation { g in
      let p = bootstrap.connect(host: self.address, port: 3338)
      p.whenSuccess {
        g.resume(returning: $0)
      }
      p.whenFailure {
        g.resume(throwing: $0)
      }
    }

    return try await WebSocketClient(context: context, handler: handler)
  }
}
