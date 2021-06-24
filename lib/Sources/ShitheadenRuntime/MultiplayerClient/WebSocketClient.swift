//
//  File.swift
//
//
//  Created by Tomas Harkema on 21/06/2021.
//

import Foundation
import ShitheadenShared

public class WebSocketClient: NSObject, URLSessionWebSocketDelegate {
  let task: URLSessionWebSocketTask
  private let onQuit: EventHandler<Void>
  private let onData: EventHandler<ServerEvent>
  public let quit: EventHandler<Void>.ReadOnly
  public let data: EventHandler<ServerEvent>.ReadOnly

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
  }

  private func receive() {
    task.receive { result in
      print(result)
      async {
      do {
        let d: Data
        switch result {
        case .success(.data(let data)):
          d = data
        case .success(.string(let string)):
          if let data = string.data(using: .utf8) {
            d = data
          }
          print("ERROR!")
          return
        case .failure(let e):
          print(e)
          return
        case .success(_):
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
  public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol p: String?) {
    print("didOpenWithProtocol \(p)")
    webSocketTask.sendPing(pongReceiveHandler: {
      print("PONSTAERT \(p), \($0)")
    })
  }

  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    onQuit.emit(())
  }

  public func write(_ turn: ServerRequest) async throws {
    print("WRITE", turn)
    return try await withUnsafeThrowingContinuation { c in
      print("WRITE turn", turn)
        let d = try! JSONEncoder().encode(turn)

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
      g.resume()
    }
  }
}
