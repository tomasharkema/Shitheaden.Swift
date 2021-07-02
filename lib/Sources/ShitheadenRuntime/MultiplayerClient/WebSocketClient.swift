//
//  File.swift
//
//
//  Created by Tomas Harkema on 21/06/2021.
//

#if !os(Linux)

  import Foundation
  import Logging
  import ShitheadenShared

  public class WebSocketClient: NSObject, URLSessionWebSocketDelegate {
    private let logger = Logger(label: "runtime.WebSocketClient")
    let task: URLSessionWebSocketTask
    private let onQuit: EventHandler<Void>
    private let onData: EventHandler<ServerEvent>
    public let quit: EventHandler<Void>.ReadOnly
    public let data: EventHandler<ServerEvent>.ReadOnly
    public private(set) var closed = false

    init(task: URLSessionWebSocketTask) {
      self.task = task
      onQuit = EventHandler()
      onData = EventHandler()
      quit = onQuit.readOnly
      data = onData.readOnly
      super.init()
      task.delegate = self
      task.resume()
      receive()
      data.on {
        switch $0 {
        case .requestSignature:
          do {
            try await self.write(.signature(Signature.getSignature()))
          } catch {
            self.logger.error("\(error)")
          }
        default:
          self.logger.info("\($0)")
        }
      }
    }

    private func receive() {
      guard !closed else {
        logger.info("Stop reading")
        return
      }
      task.receive { result in
        self.logger.info("receive: \(result)")
        async {
          do {
            let object = try JSONDecoder().decode(ServerEvent.self, from: try result.getData())
            self.logger.debug("Received: \(object)")
            await MainActor.run {
              self.onData.emit(object)
            }
          } catch {
            self.logger.error("\(error)")
          }

          self.receive()
        }
      }
    }

    deinit {
      logger.info("DEINIT")
    }

    func connected() async throws -> Self {
      let result: Void = try await withUnsafeThrowingContinuation { cont in
        task.sendPing(pongReceiveHandler: {
          if let error = $0 {
            cont.resume(throwing: error)
          } else {
            cont.resume()
          }
        })
      }
      logger.info("CONNECTED! \(result)")
      return self
    }

    var isConnected = false
    public func urlSession(
      _: URLSession,
      webSocketTask: URLSessionWebSocketTask,
      didOpenWithProtocol proto: String?
    ) {
      logger.info("didOpenWithProtocol: \(proto)")
      webSocketTask.sendPing(pongReceiveHandler: { pong in
        self.logger.info("pongReceiveHandler: \(proto) \(pong)")
      })
    }

    public func urlSession(
      _: URLSession,
      task _: URLSessionTask,
      didCompleteWithError error: Error?
    ) {
      logger.error("didCompleteWithError: \(error)")
      onQuit.emit(())
      closed = true
    }

    public func write(_ req: ServerRequest) async throws -> ServerRequest {
      try await withUnsafeThrowingContinuation { cont in
        logger.info("Write request: \(req)")
        do {
          let data = try JSONEncoder().encode(req)

          task.send(.data(data), completionHandler: {
            if let error = $0 {
              cont.resume(throwing: error)
            } else {
              cont.resume(returning: req)
            }
          })
        } catch {
          logger.error("Encoding error: \(error)")
          cont.resume(throwing: error)
        }
      }
    }

    public func close() {
      task.cancel()
      closed = true
    }
  }

  struct DataError: Error {}

  extension Result where Success == URLSessionWebSocketTask.Message {
    func getData() throws -> Data {
      switch try get() {
      case let .data(data):
        return data
      case let .string(string):
        guard let data = string.data(using: .utf8) else {
          throw DataError()
        }
        return data
      @unknown default:
        throw DataError()
      }
    }
  }

#endif
