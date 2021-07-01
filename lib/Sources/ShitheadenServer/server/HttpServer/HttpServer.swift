//
//  File.swift
//
//
//  Created by Tomas Harkema on 28/06/2021.
//

import Foundation
import NIO
import NIOSSH
import NIOSSL
import ShitheadenRuntime
import ShitheadenShared
import Vapor

final class HttpServer {
  private let logger = Logger(label: "cli.HttpServer")
  let games: AtomicDictionary<String, MultiplayerHandler>
  private var channel: Channel?

  init(games: AtomicDictionary<String, MultiplayerHandler>) {
    self.games = games
  }

  func start(group: MultiThreadedEventLoopGroup) async throws {
    // swiftlint:disable:previous function_body_length
    let app = Application(.development, .shared(group))
    app.http.server.configuration.port = 3338
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.responseCompression = .enabled

    app.middleware.use(FileMiddleware(publicDirectory: "Public"))

    let homePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(
        "shitheaden"
      )
    let certPath = homePath.appendingPathComponent("cert.pem").absoluteString
    let keyPath = homePath.appendingPathComponent("key.pem").absoluteString

    if !FileManager.default
      .fileExists(atPath: homePath.absoluteString.replacingOccurrences(of: "file://", with: ""))
    {
      try FileManager.default.createDirectory(
        at: homePath,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }

    if !FileManager.default
      .fileExists(atPath: keyPath.replacingOccurrences(of: "file://", with: "")) || !FileManager
      .default.fileExists(atPath: certPath.replacingOccurrences(of: "file://", with: ""))
    {
      logger.info("Create ssl cert...")
      let task = Process()
      task.launchPath = "/usr/bin/openssl"
      task.arguments = [
        "req", "-newkey", "rsa:2048", "-new", "-nodes", "-x509", "-days", "3650", "-keyout",
        keyPath.replacingOccurrences(of: "file://", with: ""), "-out",
        certPath.replacingOccurrences(of: "file://", with: ""),
        "-subj", "//O=shitheaden/C=NL/CN=shitheaden.harkema.io",
      ]
      task.launch()
      task.waitUntilExit()
      logger.info("Done!")
    }

    let certs = try NIOSSLCertificate
      .fromPEMFile(certPath.replacingOccurrences(of: "file://", with: ""))
      .map { NIOSSLCertificateSource.certificate($0) }
    let tls = TLSConfiguration.forServer(
      certificateChain: certs,
      privateKey: .file(keyPath.replacingOccurrences(of: "file://", with: ""))
    )

    app.http.server.configuration.supportVersions = [.two]
    app.http.server.configuration.tlsConfiguration = tls

    app.on(.POST, "playedGame", body: .collect(maxSize: "10mb")) { req -> String in
      self.logger.info("\(req)")
      let snapshot = try req.content.decode(EndGameSnapshot.self)
      #if DEBUG
        try await WriteSnapshotToDisk.write(snapshot: snapshot)
      #else
        try await WriteSnapshotToDisk.write(snapshot: snapshot)
      #endif
      return "ojoo!"
    }

    app.get("") { req in
      req.fileio.streamFile(at: "Public/index.html", mediaType: .html)
    }

    app.webSocket("terminal") { _, ws in
      do {
        let bootstrap = ClientBootstrap(group: group)
          .channelInitializer { channel in
            channel.pipeline.addHandlers([
              NIOSSHHandler(
                role: .client(.init(userAuthDelegate: SimplePasswordDelegate(username: "",
                                                                             password: ""),
                                    serverAuthDelegate: AcceptAllHostKeysDelegate())),
                allocator: channel.allocator,
                inboundChildChannelInitializer: nil
              ),
            ])
          }
          .channelOption(
            ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR),
            value: 1
          )
          .channelOption(
            ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY),
            value: 1
          )

        ws.send("Connecting...", promise: nil)

        let channel: Channel = try await withUnsafeThrowingContinuation { handler in
          do {
            let channel = try bootstrap.connect(host: "localhost", port: 3332)
            channel.whenSuccess {
              handler.resume(returning: $0)
            }
            channel.whenFailure {
              handler.resume(throwing: $0)
            }
          } catch {
            handler.resume(throwing: error)
          }
        }

        let childChannel: Channel = try channel.pipeline.handler(type: NIOSSHHandler.self)
          .flatMap { sshHandler in
            let promise = channel.eventLoop.makePromise(of: Channel.self)
            sshHandler.createChannel(promise) { childChannel, _ in
              childChannel.pipeline.addHandlers([DataToBufferCodec(), Handler(webSocket: ws)])
            }
            return promise.futureResult
          }.wait()

        ws.send("Connected!", promise: nil)

        ws.onClose.whenSuccess {
          childChannel.close().flatMap {
            channel.close()
          }.whenComplete {
            self.logger.info("CLOSED! \($0)")
          }
        }

      } catch {
        self.logger.error("Error: \(error)")
        ws.send("Error: \(error)", promise: nil)
        ws.close()
      }
    }

    app.webSocket("websocket") { _, ws in
      self.logger.info("\(ws)")
      let client = WebsocketClient(
        websocket: ws,
        games: self.games
      )
      async {
        try await client.start()
      }
    }

    try app.run()
    app.shutdown()
    logger.info("QUIT!")
    logger.info("\(app)")
  }
}

class Handler: ChannelDuplexHandler {
  typealias InboundIn = ByteBuffer
  typealias InboundOut = ByteBuffer
  typealias OutboundIn = ByteBuffer
  typealias OutboundOut = ByteBuffer

  private let webSocket: WebSocket

  init(webSocket: WebSocket) {
    self.webSocket = webSocket
  }

  func channelActive(context: ChannelHandlerContext) {
    webSocket.onText { _, text in
      context.eventLoop.execute {
        var buffer = context.channel.allocator.buffer(capacity: text.count)
        buffer.writeString(text)
        context.writeAndFlush(self.wrapOutboundOut(buffer))
      }
    }
  }

  func channelRead(context _: ChannelHandlerContext, data: NIOAny) {
    var frame = unwrapInboundIn(data)
    let string = frame.readString(length: frame.readableBytes) ?? ""
    webSocket.send(string, promise: nil)
  }

  func errorCaught(context _: ChannelHandlerContext, error: Error) {
    webSocket.send("Error: \(error)", promise: nil)
    webSocket.close()
  }
}

final class AcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate {
  func validateHostKey(
    hostKey _: NIOSSHPublicKey,
    validationCompletePromise: EventLoopPromise<Void>
  ) {
    // Do not replicate this in your own code: validate host keys! This is a
    // choice made for expedience, not for any other reason.
    validationCompletePromise.succeed(())
  }
}
