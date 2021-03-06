//
//  TelnetServerHandler.swift
//
//
//  Created by Tomas Harkema on 24/06/2021.
//

import Foundation
import Logging
import NIO
import ShitheadenRuntime
import ShitheadenShared
import AsyncAwaitHelpers

final class TelnetServerHandler: ChannelInboundHandler {
  private let logger = Logger(label: "cli.TelnetServerHandler")
  typealias InboundIn = ByteBuffer
  typealias OutboundOut = ByteBuffer

  let games: DictionaryActor<String, MultiplayerHandler>

  init(games: DictionaryActor<String, MultiplayerHandler>) {
    self.games = games
  }

  private var game: Game?
  private var task: Task<Void, Never>?

  private let quit = EventHandler<Void>()
  private let data = EventHandler<String>()
  private let handler = EventHandler<TelnetClient>()

  func channelActive(context: ChannelHandlerContext) {
    let client = TelnetClient(
      context: context,
      handler: self,
      quit: quit.readOnly,
      data: data.readOnly,
      games: games
    )
    handler.emit(client)
    Task {
      try await client.start()
    }
  }

  var buffer: String = ""
  public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    var frame = unwrapInboundIn(data)

    guard let string = frame.readString(length: frame.readableBytes) else {
      return
    }

    if string.hasSuffix("\u{3}") || string.hasSuffix("\u{6}") {
      Task {
        try await context.close().getAsync()
      }
      return
    }

    buffer += string

    guard buffer.hasSuffix("\n") || buffer.hasSuffix("\r") else {
      return
    }

    if buffer.contains("quit") {
      logger.info("EMIT QUIT!")
      quit.emit(())
    }

    self.data.emit(buffer)
    buffer = ""
  }

  public func channelReadComplete(context: ChannelHandlerContext) {
    context.flush()
  }

  func channelInactive(context _: ChannelHandlerContext) {
    logger.info("channelInactive!")
    quit.emit(())
  }

  deinit {
    logger.info("DEINIT!")
  }
}

extension EventLoopFuture {
  func getAsync() async throws -> Value {
    return try await withCheckedThrowingContinuation { res in
      whenSuccess {
        res.resume(returning: $0)
      }
      whenFailure {
        res.resume(throwing: $0)
      }
    }
  }
}
