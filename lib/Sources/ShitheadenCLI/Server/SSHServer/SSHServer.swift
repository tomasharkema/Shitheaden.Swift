//
//  SSHServer.swift
//  
//
//  Created by Tomas Harkema on 24/06/2021.
//

import Foundation
import CustomAlgo
import Foundation
import ShitheadenRuntime
import ShitheadenShared
import NIO
import NIOSSH

final class HardcodedPasswordDelegate: NIOSSHServerUserAuthenticationDelegate {
  var supportedAuthenticationMethods: NIOSSHAvailableUserAuthenticationMethods {
      .all
  }

  func requestReceived(request: NIOSSHUserAuthenticationRequest, responsePromise: EventLoopPromise<NIOSSHUserAuthenticationOutcome>) {
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
    context.write(data)
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
    context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
      context.fireErrorCaught(error)
    }
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    let data = self.unwrapInboundIn(data)

    guard case .byteBuffer(let bytes) = data.data else {
      fatalError("Unexpected read type")
    }

    guard case .channel = data.type else {
      context.fireErrorCaught(SSHServerError.invalidDataType)
      return
    }
    let b = self.wrapInboundOut(bytes)
    context.fireChannelRead(b)
  }

  func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
    let data = self.unwrapOutboundIn(data)
    context.write(self.wrapOutboundOut(SSHChannelData(type: .channel, data: .byteBuffer(data))), promise: promise)
  }
}

class SSHServer {
  let games: AtomicDictionary<String, MultiplayerHandler>
  private var channel: Channel?

  init(games: AtomicDictionary<String, MultiplayerHandler>) {
    self.games = games
  }

  private func sshChildChannelInitializer(_ channel: Channel, _ channelType: SSHChannelType) -> EventLoopFuture<Void> {
    print(channel, channelType)
    switch channelType {
    case .session:
      return channel.pipeline.addHandlers([DataToBufferCodec(), Writeback(), TelnetServerHandler(games: games)])
    case .directTCPIP(let target):
      return channel.eventLoop.makeFailedFuture(SSHServerError.invalidChannelType)
    case .forwardedTCPIP:
      return channel.eventLoop.makeFailedFuture(SSHServerError.invalidChannelType)
    }
  }

  func start(group: MultiThreadedEventLoopGroup) async throws -> Channel {

    let hostKey = NIOSSHPrivateKey(ed25519Key: .init())
    let bootstrap = ServerBootstrap(group: group)
      .childChannelInitializer { channel in
        channel.pipeline.addHandler(NIOSSHHandler(
          role: .server(.init(
            hostKeys: [hostKey],
            userAuthDelegate: HardcodedPasswordDelegate(),
            globalRequestDelegate: nil)),
          allocator: channel.allocator,
          inboundChildChannelInitializer: self.sshChildChannelInitializer
        ))
      }
      .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
      .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)

    let bind = bootstrap.bind(host: "0.0.0.0", port: 3332)

    let channel: Channel = try await withUnsafeThrowingContinuation { g in
      bind.whenSuccess {
        g.resume(returning: $0)
      }
      bind.whenFailure {
        g.resume(throwing: $0)
      }
    }

    guard let localAddress = channel.localAddress else {
      fatalError(
        "Address was unable to bind. Please check that the socket was not closed or that the address family was understood."
      )
    }
    print("Server started and listening on \(localAddress)")
    self.channel = channel
    return channel
  }
}

