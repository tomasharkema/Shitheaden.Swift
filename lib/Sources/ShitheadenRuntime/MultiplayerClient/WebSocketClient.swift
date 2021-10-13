//
//  File.swift
//
//
//  Created by Tomas Harkema on 21/06/2021.
//

#if !os(Linux)

  import Combine
  import Foundation
  import Logging
  import ShitheadenShared

  @available(iOS 15.0, macOS 15.0, *)
  public class WebSocketClient: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    private let logger = Logger(label: "runtime.WebSocketClient")
    let task: URLSessionWebSocketTask

    @Published public private(set) var data: ServerEvent?
    @Published public private(set) var quit: UUID?

    public private(set) var closed = false

    private var dataCancable: AnyCancellable?

    init(task: URLSessionWebSocketTask) {
      self.task = task
      super.init()
      #if os(iOS)
        task.delegate = self
      #endif
      receive()
      task.resume()

      dataCancable = $data.sink { data in
        async {
          switch data {
          case .requestSignature:
            do {
              try await self.write(.signature(Signature.getSignature()))
            } catch {
              self.logger.error("\(error)")
            }
          default:
            self.logger.info("\(data)")
          }
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

        do {
          let object = try JSONDecoder().decode(ServerEvent.self, from: try result.getData())
          self.logger.debug("Received: \(object)")
          self.data = object

        } catch {
          self.logger.error("\(error)")
        }

        self.receive()
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
      quit = UUID()
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
