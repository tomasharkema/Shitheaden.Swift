//
//  WebSocketHandler.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import Foundation
import NIO
import NIOHTTP1
import NIOWebSocket
import ShitheadenShared

public final class WebSocketHandler: ChannelInboundHandler {
  public typealias InboundIn = WebSocketFrame
  public typealias OutboundOut = WebSocketFrame

  public let quit = EventHandler<Void>()
  public let data = EventHandler<ServerEvent>()
  public let context = EventHandler<ChannelHandlerContext>()

  init() {
    print("INIT!")
  }

  // This is being hit, channel active won't be called as it is already added.
  public func handlerAdded(context: ChannelHandlerContext) {
    print("WebSocket handler added.")
    self.context.emit(context)
  }

  public func handlerRemoved(context _: ChannelHandlerContext) {
    print("WebSocket handler removed.")
    quit.emit(())
  }

  public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let frame = unwrapInboundIn(data)

    print("READ!", data)

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
      self.quit.emit(())
      context.close(mode: .output, promise: nil)
    }
  }
}
