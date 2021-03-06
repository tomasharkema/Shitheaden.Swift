//
//  SSHServer.swift
//
//
//  Created by Tomas Harkema on 24/06/2021.
//

import Crypto
import CustomAlgo
import Foundation
import Logging
import NIO
import NIOExtras
import NIOSSH
import ShitheadenRuntime
import ShitheadenShared
import AsyncAwaitHelpers

final class HardcodedPasswordDelegate: NIOSSHServerUserAuthenticationDelegate {
  var supportedAuthenticationMethods: NIOSSHAvailableUserAuthenticationMethods {
    .all
  }

  func requestReceived(
    request _: NIOSSHUserAuthenticationRequest,
    responsePromise: EventLoopPromise<NIOSSHUserAuthenticationOutcome>
  ) {
    responsePromise.succeed(.success)
  }
}

enum SSHServerError: Error {
  case invalidCommand
  case invalidDataType
  case invalidChannelType
  case alreadyListening
  case notListening
}

final class Writeback: ChannelDuplexHandler {
  typealias InboundIn = ByteBuffer
  typealias InboundOut = ByteBuffer
  typealias OutboundIn = ByteBuffer
  typealias OutboundOut = ByteBuffer

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    _ = context.write(data)
    context.fireChannelRead(data)
  }

  func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
    context.write(data, promise: promise)
  }
}

final class DataToBufferCodec: ChannelDuplexHandler {
  typealias InboundIn = SSHChannelData
  typealias InboundOut = ByteBuffer
  typealias OutboundIn = ByteBuffer
  typealias OutboundOut = SSHChannelData

  func handlerAdded(context: ChannelHandlerContext) {
    context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true)
      .whenFailure { error in
        context.fireErrorCaught(error)
      }
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let data = unwrapInboundIn(data)

    guard case let .byteBuffer(bytes) = data.data else {
      fatalError("Unexpected read type")
    }

    guard case .channel = data.type else {
      context.fireErrorCaught(SSHServerError.invalidDataType)
      return
    }
    let wrappedBytes = wrapInboundOut(bytes)
    context.fireChannelRead(wrappedBytes)
  }

  func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
    let data = unwrapOutboundIn(data)
    context.write(
      wrapOutboundOut(SSHChannelData(type: .channel, data: .byteBuffer(data))),
      promise: promise
    )
  }
}

final class SSHServer {
  private let logger = Logger(label: "cli.SSHServer")
  let games: DictionaryActor<String, MultiplayerHandler>
  private var channel: Channel?

  init(games: DictionaryActor<String, MultiplayerHandler>) {
    self.games = games
  }

  private func sshChildChannelInitializer(_ channel: Channel,
                                          _ channelType: SSHChannelType) -> EventLoopFuture<Void>
  {
    switch channelType {
    case .session:
      return channel.pipeline
        .addHandlers([DataToBufferCodec(), Writeback(), TelnetServerHandler(games: games)])
    case .directTCPIP:
      return channel.eventLoop.makeFailedFuture(SSHServerError.invalidChannelType)
    case .forwardedTCPIP:
      return channel.eventLoop.makeFailedFuture(SSHServerError.invalidChannelType)
    }
  }

  func start(
    quiesce: ServerQuiescingHelper,
    group: MultiThreadedEventLoopGroup
  ) async throws -> Channel {
    let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(
        "shitheaden"
      ).appendingPathComponent("ssh.pem")

    let key: Curve25519.Signing.PrivateKey
    if let data = try? Data(contentsOf: file) {
      key = try Curve25519.Signing.PrivateKey(rawRepresentation: data)
    } else {
      key = Curve25519.Signing.PrivateKey()
      try Data(key.rawRepresentation).write(to: file)
    }

    let hostKey = NIOSSHPrivateKey(ed25519Key: key)

    let bootstrap = ServerBootstrap(group: group)
      .serverChannelInitializer { channel in
        channel.pipeline.addHandler(quiesce.makeServerChannelHandler(channel: channel))
      }
      .childChannelInitializer { channel in
        channel.pipeline.addHandler(NIOSSHHandler(
          role: .server(.init(
            hostKeys: [hostKey],
            userAuthDelegate: HardcodedPasswordDelegate(),
            globalRequestDelegate: nil
          )),
          allocator: channel.allocator,
          inboundChildChannelInitializer: self.sshChildChannelInitializer
        ))
      }
      .serverChannelOption(
        ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR),
        value: 1
      )
      .serverChannelOption(
        ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY),
        value: 1
      )

    let bind = bootstrap.bind(host: "0.0.0.0", port: 3332)

    let channel: Channel = try await withCheckedThrowingContinuation { cont in
      bind.whenSuccess {
        cont.resume(returning: $0)
      }
      bind.whenFailure {
        cont.resume(throwing: $0)
      }
    }

    guard let localAddress = channel.localAddress else {
      fatalError(
        "Address was unable to bind. Please check that the socket was not closed or that the address family was understood."
      )
    }
    logger.info("Server started and listening on \(localAddress)")
    self.channel = channel
    return channel
  }
}
