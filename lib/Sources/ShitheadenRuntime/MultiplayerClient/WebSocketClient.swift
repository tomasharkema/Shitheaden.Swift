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
// import NIOSSL

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

public class EventHandler<T> {
  var events = [T]()
  var dataHandlers = AtomicDictionary<UUID, (T) async -> Void>()

  public init() {}

  public func removeOnDataHandler(id: UUID?) {
    if let id = id {
      async {
        await dataHandlers.insert(id, value: nil)
      }
    }
  }

  public func once(_ fn: @escaping (T) async -> Void) {
    let uuid = UUID()
    var hasSend = false
    let f = { (el: T) in
      if !hasSend {
        hasSend = true
        await fn(el)
      }
    }
    DispatchQueue.global().async {
      async {
        await self.dataHandlers.insert(uuid, value: f)
      }
    }
  }

  public func on(_ fn: @escaping (T) async -> Void) -> UUID {
    events.forEach { el in
      DispatchQueue.global().async {
        async {
          await fn(el)
        }
      }
    }

    events = []

    let uuid = UUID()
    async {
      await dataHandlers.insert(uuid, value: fn)
    }
    return uuid
  }

  public func emit(_ v: T) {
    async {
      if await dataHandlers.isEmpty() {
        events.append(v)
      }
      await dataHandlers.values().forEach { fn in
        DispatchQueue.global().async {
          async {
            await fn(v)
          }
        }
      }
    }
  }

  public func once() async throws -> T {
    let handler = EventHandler<()>()
    return try await withTaskCancellationHandler(handler: {
      handler.emit(())
      print("CANCEL!", handler)
    }, operation: {
      try await withUnsafeThrowingContinuation { g in
        print(" SET HANDLER!")
        handler.once { _ in
          g.resume(throwing: PlayerError.debug("QUIT"))
        }
        self.once { d in
          g.resume(returning: d)
        }
      }
    })
  }
}

public final class WebSocketHandler: ChannelInboundHandler {
  public typealias InboundIn = WebSocketFrame
  public typealias OutboundOut = WebSocketFrame

  public var quit = EventHandler<Void>()
  public var data = EventHandler<ServerEvent>()
  public private(set) var write: ((ServerRequest) async -> Void)!

//  private var context: ChannelHandlerContext!

  init() {
    print("INIT!")
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

        async {
          await self.data.emit(object)
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
    async {
      await quit.emit(())
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

//      let configuration = TLSConfiguration.clientDefault
//      let sslContext = try NIOSSLContext(configuration: configuration)

      let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
      let bootstrap = ClientBootstrap(group: group)

        // Enable SO_REUSEADDR.
        .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
        .channelInitializer { channel in

//          do {
//            channel.pipeline.addHandler(try NIOSSLClientHandler(context: sslContext, serverHostname: "shitheaden-api.harkema.io"))
//          } catch {
//            print(error)
//          }

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
      let channel = try bootstrap.connect(host: "192.168.1.102", port: 3338).wait()
//      let channel = try bootstrap.connect(host: "192.168.1.76", port: 3338).wait()
      print("CONNECTION!")
      connection = handler
      task = async {
        defer {
          try! group.syncShutdownGracefully()
        }
        try channel.closeFuture.wait()
        await handler.quit.emit(())
        connection = nil
        print("Client closed")
      }
    }
  }
}
