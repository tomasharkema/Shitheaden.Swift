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

final class HTTPInitialRequestHandler: ChannelInboundHandler, RemovableChannelHandler {
  public typealias InboundIn = HTTPClientResponsePart
  public typealias OutboundOut = HTTPClientRequestPart

  public func channelActive(context: ChannelHandlerContext) {
    print("Client connected to \(context.remoteAddress!)")

    // We are connected. It's time to send the message to the server to initialize the upgrade dance.
    var headers = HTTPHeaders()
    headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
    headers.add(name: "Content-Length", value: "\(0)")
    //    headers.add(name: "Host", value: "shitheaden-api.harkema.io")

    let requestHead = HTTPRequestHead(version: HTTPVersion(major: 1, minor: 1),
                                      method: .GET,
                                      uri: "/websocket",
                                      headers: headers)

    context.write(wrapOutboundOut(.head(requestHead)), promise: nil)

    let emptyBuffer = context.channel.allocator.buffer(capacity: 0)
    let body = HTTPClientRequestPart.body(.byteBuffer(emptyBuffer))
    context.write(wrapOutboundOut(body), promise: nil)

    context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
  }

  public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let clientResponse = unwrapInboundIn(data)

    print("Upgrade failed")

    switch clientResponse {
    case let .head(responseHead):
      print("Received status: \(responseHead.status)")
    case var .body(byteBuffer):
      if let string = byteBuffer.readString(length: byteBuffer.readableBytes) {
        print("Received: '\(string)' back from the server.")
      } else {
        print("Received the line back from the server.")
      }
    case .end:
      print("Closing channel.")
      context.close(promise: nil)
    }
  }

  public func handlerRemoved(context _: ChannelHandlerContext) {
    print("HTTP handler removed.")
  }

  public func errorCaught(context: ChannelHandlerContext, error: Error) {
    print("error: ", error)

    // As we are not really interested getting notified on success or failure
    // we just pass nil as promise to reduce allocations.
    context.close(promise: nil)
  }
}
