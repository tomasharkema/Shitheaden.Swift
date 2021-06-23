//
//  File.swift
//
//
//  Created by Tomas Harkema on 21/06/2021.
//

import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import ShitheadenShared

public class WebSocketClient {
  private weak var context: ChannelHandlerContext?
  private weak var handler: WebSocketHandler?

  public let quit: EventHandler<Void>
  public let data: EventHandler<ServerEvent>

  init(context: ChannelHandlerContext, handler: WebSocketHandler) {
    self.context = context
    self.handler = handler

    quit = handler.quit
    data = handler.data
  }

  public func write(_ turn: ServerRequest) async throws {
    guard let context = context, let handler = handler else {
      assertionFailure("WHAT?")
      throw NSError(domain: "", code: 0, userInfo: nil)
    }

    return try await withUnsafeThrowingContinuation { c in
      print("WRITE turn", turn)
      context.eventLoop.execute {
        let d = try! JSONEncoder().encode(turn)

        var buffer = context.channel.allocator.buffer(capacity: d.count)
        buffer.writeBytes(d)
        let frame = WebSocketFrame(fin: true, opcode: .binary, data: buffer)
        let p = context.writeAndFlush(handler.wrapOutboundOut(frame))
        p.whenSuccess { c.resume(returning: ()) }

        p.whenFailure {
          c.resume(throwing: $0)
        }
      }
    }
  }

  public func close() async {
    return await withUnsafeContinuation { g in
      context?.eventLoop.execute {
        let p = self.context?.close(mode: .all)
        p?.whenComplete { _ in
          g.resume()
        }
      }
    }
  }
}
