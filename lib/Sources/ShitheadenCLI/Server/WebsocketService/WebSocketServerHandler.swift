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

  let games: AtomicDictonary<String, MultiplayerHandler>

  init(games: AtomicDictonary<String, MultiplayerHandler>) {
    self.games = games
  }

  private var awaitingClose: Bool = false

  private var handleData = [(ServerRequest) -> Void]()
  private var onClose = [() -> Void]()
  private var game: Game?
  private var task: Task.Handle<Void, Never>?

  private var handlers = [String: WebsocketClient]()

  public func handlerAdded(context: ChannelHandlerContext) {
    print("handlerAdded", context.name)
    let c = WebsocketClient(context: context, handler: self, games: games)
    handlers[context.name] = c
    async {
      await c.start()
    }
  }

  public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let frame = unwrapInboundIn(data)

    print(frame)

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

      handlers[context.name]?._onWrite(sr)

//      handleData?(sr)
    case .text, .continuation, .pong:
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

//  private func startGame(context: ChannelHandlerContext) {
//    guard context.channel.isActive else { return }
//
//    // We can't send if we sent a close message.
//    guard !awaitingClose else { return }
//
//    let id = UUID()
//
//    task = asyncDetached {
//      let game = Game(players: [
//        Player(
//          name: "West (Unfair)",
//          position: .west,
//          ai: CardRankingAlgoWithUnfairPassing()
//        ),
//        Player(
//          name: "Noord",
//          position: .noord,
//          ai: CardRankingAlgo()
//        ),
//        Player(
//          name: "Oost",
//          position: .oost,
//          ai: CardRankingAlgo()
//        ),
//        Player(
//          name: "Zuid (JIJ)",
//          position: .zuid,
//          ai: UserInputAIJson(id: id) { request in
//            print("READ! UserInputAIJson")
//            return await withUnsafeContinuation { g in
//              send(.action(request))
//              self.handleData = {
//                g.resume(returning: $0)
//                self.handleData = nil
//              }
//            }
//          } renderHandler: { game, error in
//            if let error = error {
//              send(.error(.playerError(error)))
//            }
//            send(.render(game))
//          }
//        ),
//      ], slowMode: true)
//      self.game = game
//      asyncDetached(priority: .background) {
//        await game.startGame()
//      }
//    }
//  }

  private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
    for h in handlers[context.name]?.onQuit ?? [] {
      async {
        await h()
      }
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

class WebsocketClient: Client {
  let context: ChannelHandlerContext
  let handler: WebSocketServerHandler
  var onQuit = [() async -> Void]()
  let games: AtomicDictonary<String, MultiplayerHandler>

  init(
    context: ChannelHandlerContext,
    handler: WebSocketServerHandler,
    games: AtomicDictonary<String, MultiplayerHandler>
  ) {
    self.context = context
    self.handler = handler
    self.games = games
  }

  func start() async {
    await send(.requestMultiplayerChoice)
    let choice: ServerRequest? = await read()
    switch choice {
    case let .joinMultiplayer(code):
      await joinGame(code: code)
    case .startMultiplayer:
      await startMultiplayer()

    case .multiplayerRequest:
      return await start()

    case .quit:
      for onQuit in onQuit {
        await onQuit()
      }
      context.close()

    case .startGame:
      print("OJOO!")

    case .none:
      return await start()
    }
  }

  private func joinGame(code: String) async {
    if let game = await games.get(code) {
      let id = UUID()
      await game.join(id: id, client: self)
      await game.finished()
    } else {
      await send(.error(error: .gameNotFound(code: code)))
      return await start()
    }
  }

  private func startMultiplayer() async {
    let id = UUID()
    let promise = Promise()
    let pair = MultiplayerHandler(challenger: (id, self), finshedTask: promise.task)
    await games.insert(pair.code, value: pair)

    await pair.waitForStart()
  }

  func send(_ event: ServerEvent) async {
    return await withUnsafeContinuation { g in
      self.context.eventLoop.execute {
        // We can't really check for error here, but it's also not the purpose of the
        // example so let's not worry about it.
        do {
          let data = try JSONEncoder().encode(event)

          var buffer = self.context.channel.allocator.buffer(capacity: data.count)
          buffer.writeBytes(data)

          let frame = WebSocketFrame(fin: true, opcode: .binary, data: buffer)
          self.context.writeAndFlush(self.handler.wrapOutboundOut(frame)).whenComplete {
            print($0)
            g.resume()
          }
        } catch {
          print(error)
        }
      }
    }
  }

  private var consume = [UUID: (ServerRequest) -> Void]()
  func _onWrite(_ ev: ServerRequest) {
//    consume?(ev)
    for c in consume {
      c.value(ev)
    }
  }

  func read() async -> ServerRequest {
    let id = UUID()
    return await withUnsafeContinuation { g in
      consume[id] = {
        g.resume(returning: $0)
        self.consume[id] = nil
      }
    }
  }
}

// extension ChannelHandlerContext {
//  func send(event: ServerEvent) async {
//    return await withUnsafeContinuation { g in
//      eventLoop.execute {
//        // We can't really check for error here, but it's also not the purpose of the
//        // example so let's not worry about it.
//
//        let data = try! JSONEncoder().encode(event)
//
//        var buffer = self.channel.allocator.buffer(capacity: data.count)
//        buffer.writeBytes(data)
//
//        let frame = WebSocketFrame(fin: true, opcode: .binary, data: buffer)
//        writeAndFlush(self.wrapOutboundOut(frame)).whenFailure { (_: Error) in
//          close(promise: nil)
//        }
//        g.resume()
//      }
//    }
//  }
// }
