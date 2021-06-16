////
////  File.swift
////
////
////  Created by Tomas Harkema on 16/06/2021.
////
//
// import Foundation
// import NIO
// import NIOSSH
//
// class SshServer {
//
//  private func sshChildChannelInitializer(_ channel: Channel, _ channelType: SSHChannelType) -> EventLoopFuture<Void> {
//    switch channelType {
//    case .session:
//      return channel.pipeline.addHandler(ExampleExecHandler())
//    case .directTCPIP(let target):
//      let (ours, theirs) = GlueHandler.matchedPair()
//
//      return channel.pipeline.addHandlers([DataToBufferCodec(), ours]).flatMap {
//        createOutboundConnection(targetHost: target.targetHost, targetPort: target.targetPort, loop: channel.eventLoop)
//      }.flatMap { targetChannel in
//        targetChannel.pipeline.addHandler(theirs)
//      }
//    case .forwardedTCPIP:
//      return channel.eventLoop.makeFailedFuture(SSHServerError.invalidChannelType)
//    }
//  }
//
//  func startServer() {
//    do {
//      let hostKey = NIOSSHPrivateKey(ed25519Key: .init())
//      let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
//      let bootstrap = ServerBootstrap(group: group)
//        .childChannelInitializer { channel in
//          channel.pipeline.addHandlers([NIOSSHHandler(role: .server(.init(hostKeys: [hostKey], userAuthDelegate: HardcodedPasswordDelegate(), globalRequestDelegate: RemotePortForwarderGlobalRequestDelegate())), allocator: channel.allocator, inboundChildChannelInitializer: self.sshChildChannelInitializer), ErrorHandler()])
//        }
//        .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
//        .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)
//
//      let channel = try bootstrap.bind(host: "0.0.0.0", port: 2222).wait()
//      try channel.closeFuture.wait()
//    } catch {
//      print(error)
//    }
//  }
// }
//
// final class HardcodedPasswordDelegate: NIOSSHServerUserAuthenticationDelegate {
//  var supportedAuthenticationMethods: NIOSSHAvailableUserAuthenticationMethods {
//      .password
//  }
//
//  func requestReceived(request: NIOSSHUserAuthenticationRequest, responsePromise: EventLoopPromise<NIOSSHUserAuthenticationOutcome>) {
//    guard case .password(let passwordRequest) = request.request else {
//      responsePromise.succeed(.failure)
//      return
//    }
//
//    if passwordRequest.password == "gottagofast" {
//      responsePromise.succeed(.success)
//    } else {
//      responsePromise.succeed(.failure)
//    }
//  }
// }
//
//
// final class RemotePortForwarderGlobalRequestDelegate: GlobalRequestDelegate {
//
//  func tcpForwardingRequest(_ request: GlobalRequest.TCPForwardingRequest, handler: NIOSSHHandler, promise: EventLoopPromise<GlobalRequest.TCPForwardingResponse>) {
//    switch request {
//    case .listen(host: let host, port: let port):
//        promise.fail(SSHServerError.alreadyListening)
//    case .cancel:
//
//        promise.fail(SSHServerError.notListening)
//
//    }
//  }
// }
//
// enum SSHServerError: Error {
//  case invalidCommand
//  case invalidDataType
//  case invalidChannelType
//  case alreadyListening
//  case notListening
// }
//
// final class ErrorHandler: ChannelInboundHandler {
//  typealias InboundIn = Any
//
//  func errorCaught(context: ChannelHandlerContext, error: Error) {
//    print("Error in pipeline: \(error)")
//    context.close(promise: nil)
//  }
// }
//
//
// final class ExampleExecHandler: ChannelDuplexHandler {
//  typealias InboundIn = SSHChannelData
//  typealias InboundOut = ByteBuffer
//  typealias OutboundIn = ByteBuffer
//  typealias OutboundOut = SSHChannelData
//
//  let queue = DispatchQueue(label: "background exec")
//  var process: Process?
//  var environment: [String: String] = [:]
//
//  func handlerAdded(context: ChannelHandlerContext) {
//    context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
//      context.fireErrorCaught(error)
//    }
//  }
//
//  func channelInactive(context: ChannelHandlerContext) {
//    self.queue.sync {
//      if let process = self.process, process.isRunning {
//        process.terminate()
//      }
//    }
//    context.fireChannelInactive()
//  }
//
//  func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
//    switch event {
//    case let event as SSHChannelRequestEvent.ExecRequest:
//      self.exec(event, channel: context.channel)
//
//    case let event as SSHChannelRequestEvent.EnvironmentRequest:
//      self.queue.sync {
//        environment[event.name] = event.value
//      }
//
//    default:
//      context.fireUserInboundEventTriggered(event)
//    }
//  }
//
//  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
//    let data = self.unwrapInboundIn(data)
//
//    guard case .byteBuffer(let bytes) = data.data else {
//      fatalError("Unexpected read type")
//    }
//
//    guard case .channel = data.type else {
//      context.fireErrorCaught(SSHServerError.invalidDataType)
//      return
//    }
//
//    context.fireChannelRead(self.wrapInboundOut(bytes))
//  }
//
//  func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
//    let data = self.unwrapOutboundIn(data)
//    context.write(self.wrapOutboundOut(SSHChannelData(type: .channel, data: .byteBuffer(data))), promise: promise)
//  }
//
//  private func exec(_ event: SSHChannelRequestEvent.ExecRequest, channel: Channel) {
//    // Kick this off to a background queue
//    self.queue.async {
//      do {
//        // We're not a shell, so we just do our "best".
//        let executable = URL(fileURLWithPath: "/usr/local/bin/bash")
//        let process = Process()
//        process.executableURL = executable
//        process.arguments = ["-c", event.command]
//        process.terminationHandler = { process in
//          // The process terminated. Check its return code, fire it, and then move on.
//          let rcode = process.terminationStatus
//          channel.triggerUserOutboundEvent(SSHChannelRequestEvent.ExitStatus(exitStatus: Int(rcode))).whenComplete { _ in
//            channel.close(promise: nil)
//          }
//        }
//
//        let inPipe = Pipe()
//        let outPipe = Pipe()
//        let errPipe = Pipe()
//
//        process.standardInput = inPipe
//        process.standardOutput = outPipe
//        process.standardError = errPipe
//        process.environment = self.environment
//
//        let (ours, theirs) = GlueHandler.matchedPair()
//        try channel.pipeline.addHandler(ours).wait()
//
//        _ = try NIOPipeBootstrap(group: channel.eventLoop)
//          .channelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
//          .channelInitializer { pipeChannel in
//            pipeChannel.pipeline.addHandler(theirs)
//          }.withPipes(inputDescriptor: outPipe.fileHandleForReading.fileDescriptor, outputDescriptor: inPipe.fileHandleForWriting.fileDescriptor).wait()
//
//        // Ok, great, we've sorted stdout and stdin. For stderr we need a different strategy: we just park a thread for this.
//        DispatchQueue(label: "stderrorwhatever").async {
//          while true {
//            let data = errPipe.fileHandleForReading.readData(ofLength: 1024)
//
//            guard data.count > 0 else {
//              // Stderr is done
//              return
//            }
//
//            var buffer = channel.allocator.buffer(capacity: data.count)
//            buffer.writeContiguousBytes(data)
//            channel.write(SSHChannelData(type: .stdErr, data: .byteBuffer(buffer)), promise: nil)
//          }
//        }
//
//        if event.wantReply {
//          channel.triggerUserOutboundEvent(ChannelSuccessEvent(), promise: nil)
//        }
//
//        try process.run()
//        self.process = process
//      } catch {
//        if event.wantReply {
//          channel.triggerUserOutboundEvent(ChannelFailureEvent()).whenComplete { _ in
//            channel.close(promise: nil)
//          }
//        } else {
//          channel.close(promise: nil)
//        }
//      }
//    }
//  }
// }
//
//
// final class GlueHandler {
//  private var partner: GlueHandler?
//
//  private var context: ChannelHandlerContext?
//
//  private var pendingRead: Bool = false
//
//  private init() {}
// }
//
// extension GlueHandler {
//  static func matchedPair() -> (GlueHandler, GlueHandler) {
//    let first = GlueHandler()
//    let second = GlueHandler()
//
//    first.partner = second
//    second.partner = first
//
//    return (first, second)
//  }
// }
//
// extension GlueHandler {
//  private func partnerWrite(_ data: NIOAny) {
//    self.context?.write(data, promise: nil)
//  }
//
//  private func partnerFlush() {
//    self.context?.flush()
//  }
//
//  private func partnerWriteEOF() {
//    self.context?.close(mode: .output, promise: nil)
//  }
//
//  private func partnerCloseFull() {
//    self.context?.close(promise: nil)
//  }
//
//  private func partnerBecameWritable() {
//    if self.pendingRead {
//      self.pendingRead = false
//      self.context?.read()
//    }
//  }
//
//  private var partnerWritable: Bool {
//    self.context?.channel.isWritable ?? false
//  }
// }
//
// extension GlueHandler: ChannelDuplexHandler {
//  typealias InboundIn = NIOAny
//  typealias OutboundIn = NIOAny
//  typealias OutboundOut = NIOAny
//
//  func handlerAdded(context: ChannelHandlerContext) {
//    self.context = context
//
//    // It's possible our partner asked if we were writable, before, and we couldn't answer.
//    // Consider updating it.
//    if context.channel.isWritable {
//      self.partner?.partnerBecameWritable()
//    }
//  }
//
//  func handlerRemoved(context: ChannelHandlerContext) {
//    self.context = nil
//    self.partner = nil
//  }
//
//  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
//    self.partner?.partnerWrite(data)
//  }
//
//  func channelReadComplete(context: ChannelHandlerContext) {
//    self.partner?.partnerFlush()
//  }
//
//  func channelInactive(context: ChannelHandlerContext) {
//    self.partner?.partnerCloseFull()
//  }
//
//  func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
//    if let event = event as? ChannelEvent, case .inputClosed = event {
//      // We have read EOF.
//      self.partner?.partnerWriteEOF()
//    }
//  }
//
//  func errorCaught(context: ChannelHandlerContext, error: Error) {
//    self.partner?.partnerCloseFull()
//  }
//
//  func channelWritabilityChanged(context: ChannelHandlerContext) {
//    if context.channel.isWritable {
//      self.partner?.partnerBecameWritable()
//    }
//  }
//
//  func read(context: ChannelHandlerContext) {
//    if let partner = self.partner, partner.partnerWritable {
//      context.read()
//    } else {
//      self.pendingRead = true
//    }
//  }
// }
//
//
// final class DataToBufferCodec: ChannelDuplexHandler {
//  typealias InboundIn = SSHChannelData
//  typealias InboundOut = ByteBuffer
//  typealias OutboundIn = ByteBuffer
//  typealias OutboundOut = SSHChannelData
//
//  func handlerAdded(context: ChannelHandlerContext) {
//    context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
//      context.fireErrorCaught(error)
//    }
//  }
//
//  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
//    let data = self.unwrapInboundIn(data)
//
//    guard case .byteBuffer(let bytes) = data.data else {
//      fatalError("Unexpected read type")
//    }
//
//    guard case .channel = data.type else {
//      context.fireErrorCaught(SSHServerError.invalidDataType)
//      return
//    }
//
//    context.fireChannelRead(self.wrapInboundOut(bytes))
//  }
//
//  func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
//    let data = self.unwrapOutboundIn(data)
//    context.write(self.wrapOutboundOut(SSHChannelData(type: .channel, data: .byteBuffer(data))), promise: promise)
//  }
// }
//
// func createOutboundConnection(targetHost: String, targetPort: Int, loop: EventLoop) -> EventLoopFuture<Channel> {
//  ClientBootstrap(group: loop).channelInitializer { channel in
//    channel.eventLoop.makeSucceededFuture(())
//  }.connect(host: targetHost, port: targetPort)
// }
