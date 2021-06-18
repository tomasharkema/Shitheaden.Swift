
import CustomAlgo
import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import ShitheadenRuntime

let websocketResponse = """
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Swift NIO WebSocket Test Page</title>
  </head>
  <body>
    <h1>WebSocket Stream</h1>
    <div id="websocket-stream"></div>
    <script>
        var wsconnection = new WebSocket("ws://localhost:3338/websocket");
        wsconnection.onmessage = function (msg) {
            var element = document.createElement("p");
            element.innerHTML = msg.data;
            var textDiv = document.getElementById("websocket-stream");
            textDiv.insertBefore(element, null);
        };
    </script>
  </body>
</html>
"""

private final class HTTPHandler: ChannelInboundHandler, RemovableChannelHandler {
  typealias InboundIn = HTTPServerRequestPart
  typealias OutboundOut = HTTPServerResponsePart

  private var responseBody: ByteBuffer!

  func handlerAdded(context: ChannelHandlerContext) {
    responseBody = context.channel.allocator.buffer(string: websocketResponse)
  }

  func handlerRemoved(context _: ChannelHandlerContext) {
    responseBody = nil
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let reqPart = unwrapInboundIn(data)

    // We're not interested in request bodies here: we're just serving up GET responses
    // to get the client to initiate a websocket request.
    guard case let .head(head) = reqPart else {
      return
    }

    // GETs only.
    guard case .GET = head.method else {
      respond405(context: context)
      return
    }

    var headers = HTTPHeaders()
    headers.add(name: "Content-Type", value: "text/html")
    headers.add(name: "Content-Length", value: String(responseBody.readableBytes))
    headers.add(name: "Connection", value: "close")
    let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1),
                                        status: .ok,
                                        headers: headers)
    context.write(wrapOutboundOut(.head(responseHead)), promise: nil)
    context.write(wrapOutboundOut(.body(.byteBuffer(responseBody))), promise: nil)
    context.write(wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
      context.close(promise: nil)
    }
    context.flush()
  }

  private func respond405(context: ChannelHandlerContext) {
    var headers = HTTPHeaders()
    headers.add(name: "Connection", value: "close")
    headers.add(name: "Content-Length", value: "0")
    let head = HTTPResponseHead(version: .http1_1,
                                status: .methodNotAllowed,
                                headers: headers)
    context.write(wrapOutboundOut(.head(head)), promise: nil)
    context.write(wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
      context.close(promise: nil)
    }
    context.flush()
  }
}

private final class WebSocketTimeHandler: ChannelInboundHandler {
  typealias InboundIn = WebSocketFrame
  typealias OutboundOut = WebSocketFrame

  private var awaitingClose: Bool = false

  private var handleData: ((String) -> ())?
  private var game: Game?
  private var task: Task.Handle<Void, Never>?

  public func handlerAdded(context: ChannelHandlerContext) {
    startGame(context: context)
  }

  public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let frame = unwrapInboundIn(data)

    switch frame.opcode {
    case .connectionClose:
      receivedClose(context: context, frame: frame)
    case .ping:
      pong(context: context, frame: frame)
    case .text:
      var data = frame.unmaskedData
      let text = data.readString(length: data.readableBytes) ?? ""
      print(text)
      handleData?(text)
    case .binary, .continuation, .pong:
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

  private func startGame(context: ChannelHandlerContext) {
    guard context.channel.isActive else { return }

    // We can't send if we sent a close message.
    guard !awaitingClose else { return }

    let send = { (string: String) in
      context.eventLoop.execute {
        // We can't really check for error here, but it's also not the purpose of the
        // example so let's not worry about it.
        var buffer = context.channel.allocator.buffer(capacity: string.count)
        buffer.writeString("\(string)")

        let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
        context.writeAndFlush(self.wrapOutboundOut(frame)).whenFailure { (_: Error) in
          context.close(promise: nil)
        }
      }
    }
    task = async {
      let game = Game(players: [
        Player(
          name: "Zuid (JIJ)",
          position: .zuid,
          ai: UserInputAI {
            print("READ!")
            return await withUnsafeContinuation { g in
              send("{\"action\":\"REQUEST_TURN\"}")
              self.handleData = {
                g.resume(returning: $0)
                self.handleData = nil
              }
            }
          } render: { _ in }
        ),
        Player(
          name: "West (Unfair)",
          position: .west,
          ai: CardRankingAlgoWithUnfairPassing()
        ),
        Player(
          name: "Noord",
          position: .noord,
          ai: CardRankingAlgo()
        ),
        Player(
          name: "Oost",
          position: .oost,
          ai: CardRankingAlgo()
        ),
      ], slowMode: true, render: { game, _ in

        guard let data = try? JSONEncoder().encode(game),
              let string = String(data: data, encoding: .utf8)
        else {
          return
        }

        send(string)
      })
      self.game = game
      await game.startGame()
    }
  }

  private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
    task?.cancel()
    game = nil
    // Handle a received close frame. In websockets, we're just going to send the close
    // frame and then close, unless we already sent our own close frame.
    if awaitingClose {
      // Cool, we started the close and were waiting for the user. We're done.
      context.close(promise: nil)
    } else {
      // This is an unsolicited close. We're going to send a response frame and
      // then, when we've sent it, close up shop. We should send back the close code the remote
      // peer sent us, unless they didn't send one at all.
      var data = frame.unmaskedData
      let closeDataCode = data.readSlice(length: 2) ?? ByteBuffer()
      let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: closeDataCode)
      _ = context.write(wrapOutboundOut(closeFrame)).map { () in
        context.close(promise: nil)
      }
    }
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
    // We have hit an error, we want to close. We do that by sending a close frame and then
    // shutting down the write side of the connection.
    var data = context.channel.allocator.buffer(capacity: 2)
    data.write(webSocketErrorCode: .protocolError)
    let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
    context.write(wrapOutboundOut(frame)).whenComplete { (_: Result<Void, Error>) in
      context.close(mode: .output, promise: nil)
    }
    awaitingClose = true
  }
}

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
