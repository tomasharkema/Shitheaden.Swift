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

// The HTTP handler to be used to initiate the request.
// This initial request will be adapted by the WebSocket upgrader to contain the upgrade header parameters.
// Channel read will only be called if the upgrade fails.

private final class HTTPInitialRequestHandler: ChannelInboundHandler, RemovableChannelHandler {
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

// The web socket handler to be used once the upgrade has occurred.
// One added, it sends a ping-pong round trip with "Hello World" data.
// It also listens for any text frames from the server and prints them.

public final class WebSocketHandler: ChannelInboundHandler {
  public typealias InboundIn = WebSocketFrame
  public typealias OutboundOut = WebSocketFrame

  public var onQuit = [() -> Void]()
  public var onData = [(ServerEvent) -> Void]()
  public private(set) var write: ((ServerRequest) async -> Void)!

//  private var context: ChannelHandlerContext!

  init() {
    print("INIT!")
  }

  func callOnQuit() {
    for onQuit in onQuit {
      onQuit()
    }
  }

  // This is being hit, channel active won't be called as it is already added.
  public func handlerAdded(context: ChannelHandlerContext) {
    print("WebSocket handler added.")
//    context = context

    write = { turn in
      await withUnsafeContinuation { c in
        print("WRITE turn", turn)
        context.eventLoop.execute {
          let d = try! JSONEncoder().encode(turn)
          print(d)
          var buffer = context.channel.allocator.buffer(capacity: d.count)
          buffer.writeBytes(d)
          let frame = WebSocketFrame(fin: true, opcode: .binary, data: buffer)
          let p = context.writeAndFlush(self.wrapOutboundOut(frame))
          p.whenSuccess { print($0) }
          p.whenComplete { print($0)
            c.resume()
          }
          p.whenFailure {
            print($0)
          }
          p.whenComplete { (_: Result<Void, Error>) in
          }
        }
      }
    }
  }

  public func handlerRemoved(context _: ChannelHandlerContext) {
    print("WebSocket handler removed.")
  }

  public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let frame = unwrapInboundIn(data)

    switch frame.opcode {
    case .pong:
      pong(context: context, frame: frame)
    case .binary:
      var data = frame.unmaskedData
      let text = data.readBytes(length: data.readableBytes)!
      print("Websocket: Received \(String(data: Data(text), encoding: .utf8))")
      do {
        let object = try JSONDecoder().decode(ServerEvent.self, from: Data(text))

        for onData in onData {
          onData(object)
        }

      } catch {
        print(error)
      }
    case .connectionClose:
      receivedClose(context: context, frame: frame)
    case .text, .continuation, .ping:
      // We ignore these frames.
      break
    default:
      // Unknown frames are errors.
      closeOnError(context: context)
    }
  }

  public func channelReadComplete(context: ChannelHandlerContext) {
    context.flush()
  }

  private func receivedClose(context: ChannelHandlerContext, frame _: WebSocketFrame) {
    // Handle a received close frame. We're just going to close.
    print("Received Close instruction from server")
    context.close(promise: nil)
  }

  private func pong(context: ChannelHandlerContext, frame: WebSocketFrame) {
    var frameData = frame.data
    let maskingKey = frame.maskKey

    if let maskingKey = maskingKey {
      frameData.webSocketUnmask(maskingKey)
    }

    let responseFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
    context.write(wrapOutboundOut(responseFrame), promise: nil)
  }

  private func closeOnError(context: ChannelHandlerContext) {
    for onQuit in onQuit {
      onQuit()
    }

    // We have hit an error, we want to close. We do that by sending a close frame and then
    // shutting down the write side of the connection. The server will respond with a close of its own.
    var data = context.channel.allocator.buffer(capacity: 2)
    data.write(webSocketErrorCode: .protocolError)
    let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
    let p = context.write(wrapOutboundOut(frame))
    p.whenSuccess { print($0) }
    p.whenComplete { print($0) }
    p.whenFailure {
      print($0)
    }
    p.whenComplete { (_: Result<Void, Error>) in
      context.close(mode: .output, promise: nil)
    }
  }
}

public class WebSocketClient {
  public private(set) var connection: WebSocketHandler? {
    didSet {
      if let connection = connection {
        async {
          let c = onConnected
          await MainActor.run {
            c?(connection)
          }
        }
      }
    }
  }

  private var onConnected: ((WebSocketHandler) -> Void)?

  public init() {}

  public func setOnConnected(_ fn: @escaping (WebSocketHandler) -> Void) {
    onConnected = fn
  }

  var task: Task.Handle<Void, Error>?

  public func start() async throws {
    async {
      let handler = WebSocketHandler()

      let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
      let bootstrap = ClientBootstrap(group: group)
        // Enable SO_REUSEADDR.
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

      let channel = try bootstrap.connect(host: "192.168.1.76", port: 3338).wait()
      print("CONNECTION!")
      connection = handler
      task = async {
        defer {
          try! group.syncShutdownGracefully()
        }
        try channel.closeFuture.wait()
        handler.callOnQuit()
        connection = nil
        print("Client closed")
      }
    }
  }
}
