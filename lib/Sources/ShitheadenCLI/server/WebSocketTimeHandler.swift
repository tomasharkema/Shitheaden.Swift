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

final class WebSocketTimeHandler: ChannelInboundHandler {
  typealias InboundIn = WebSocketFrame
  typealias OutboundOut = WebSocketFrame

  private var awaitingClose: Bool = false

  private var handleData: ((String) -> Void)?
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

    let id = UUID()

    task = async {
      let game = Game(players: [
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
        Player(
          name: "Zuid (JIJ)",
          position: .zuid,
          ai: UserInputAI(id: id) {
            print("READ!")
            return await withUnsafeContinuation { g in
              send("{\"action\":\"REQUEST_TURN\"}")
              self.handleData = {
                g.resume(returning: $0)
                self.handleData = nil
              }
            }
          } render: {
            send("{\"error\":\"\($0)\"}")
          }
        ),
      ], slowMode: true, localUserUUID: id, render: { game, _ in

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
