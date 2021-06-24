//
//  WebSocketHandler.swift
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
import ShitheadenShared

final class WebSocketServerHandler: ChannelInboundHandler {
  typealias InboundIn = WebSocketFrame
  typealias OutboundOut = WebSocketFrame

  let games: AtomicDictionary<String, MultiplayerHandler>

  init(games: AtomicDictionary<String, MultiplayerHandler>) {
    self.games = games
  }

  private var awaitingClose: Bool = false
  private var game: Game?
  private var task: Task.Handle<Void, Never>?

  private let quit = EventHandler<Void>()
  private let data = EventHandler<ServerRequest>()
  private let handler = EventHandler<WebsocketClient>()

  public func handlerAdded(context: ChannelHandlerContext) {
    print("HANDLER ADDED")
    let c = WebsocketClient(context: context, handler: self, quit: quit, data: data, games: games)
    handler.emit(c)
    async {
      await c.start()
    }
  }

  func channelActive(context: ChannelHandlerContext) {
    print("HANDLER ACTIVE")
  }

  public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let frame = unwrapInboundIn(data)

    switch frame.opcode {
    case .connectionClose:
      receivedClose(context: context, frame: frame)
    case .ping:
      pong(context: context, frame: frame)
    case .binary:
      var data = frame.unmaskedData
      let d = data
        .readBytes(length: data.readableBytes)! // data.readString(length: data.readableBytes) ?? ""
      print(d)
      let sr = try! JSONDecoder().decode(ServerRequest.self, from: Data(d))
      print(sr)

      self.data.emit(sr)

//      handleData?(sr)
    case .text:

      var data = frame.unmaskedData
      let d = data.readString(length: data.readableBytes)!
      print(d)
      let sr = try! JSONDecoder().decode(ServerRequest.self, from: d.data(using: .utf8)!)
      print(sr)
      print("READ!", context.name)

      self.data.emit(sr)

    case .continuation, .pong:
      // We ignore these frames.
      break
    default:
      // Unknown frames are errors.
      closeOnError(context: context)
    }
  }

  public func channelReadComplete(context: ChannelHandlerContext) {
    print("FLUSH")
    context.flush()
  }

  deinit {
    print("DEINIT!")
  }

  private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
    async {
      self.quit.emit(())
    }

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
