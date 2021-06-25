//
//  File.swift
//
//
//  Created by Tomas Harkema on 21/06/2021.
//

#if !os(Linux)

  import Foundation
  import ShitheadenShared

  public class WebSocketClient: NSObject, URLSessionWebSocketDelegate {
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
            let url = Bundle.main.url(forResource: "lib", withExtension: "sig")!
            async let string = try String(contentsOf: url)
              .replacingOccurrences(of: "  -\n", with: "")
            try await self.write(.signature(string))
          } catch {
            print(error)
          }
        default:
          print($0)
        }
      }
    }

    private func receive() {
      guard !closed else {
        print("STOP READING!")
        return
      }
      task.receive { result in
        print(result)
        async {
          do {
            let d: Data
            switch result {
            case let .success(.data(data)):
              d = data
            case let .success(.string(string)):
              if let data = string.data(using: .utf8) {
                d = data
              }
              print("ERROR!")
              return
            case let .failure(e):
              print(e)
              return
            case .success:
              print(result)
              return
            }
            print("d", d)

            let o = try JSONDecoder().decode(ServerEvent.self, from: d)
            print("d", o)
            await MainActor.run {
              self.onData.emit(o)
            }
          } catch {
            print(error)
          }
        }
        self.receive()
      }
    }

    deinit {
      print("DERP!")
    }

    func connected() async throws -> Self {
      let _: Void = try await withUnsafeThrowingContinuation { g in
        task.sendPing(pongReceiveHandler: {
          if let error = $0 {
            g.resume(throwing: error)
          } else {
            g.resume()
          }
        })
      }
      print("CONNECTED!")
      return self
    }

    var isConnected = false
    public func urlSession(
      _: URLSession,
      webSocketTask: URLSessionWebSocketTask,
      didOpenWithProtocol p: String?
    ) {
      print("didOpenWithProtocol \(p)")
      webSocketTask.sendPing(pongReceiveHandler: {
        print("PONSTAERT \(p), \($0)")
      })
    }

    public func urlSession(_: URLSession, task _: URLSessionTask, didCompleteWithError _: Error?) {
      onQuit.emit(())
      closed = true
    }

    public func write(_ req: ServerRequest) async throws {
      print("WRITE", req)
      return try await withUnsafeThrowingContinuation { c in
        print("WRITE turn", req)
        let d = try! JSONEncoder().encode(req)

        task.send(.data(d), completionHandler: {
          if let error = $0 {
            c.resume(throwing: error)
          } else {
            c.resume()
          }
        })
      }
    }

    public func close() async {
      return await withUnsafeContinuation { g in
        task.cancel()
        closed = true
        g.resume()
      }
    }
  }

#endif
