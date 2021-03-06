//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//
#if !os(Linux)
  import Foundation
  import ShitheadenShared

@available(iOS 15.0, macOS 15.0, *)
  public class WebSocketGameClient {
    private let address =
      URL(
        string: "\(Host.host.absoluteString.replacingOccurrences(of: "http", with: "ws"))/websocket"
      )!

    public init() {}

    public func start() async throws -> WebSocketClient {
      try await WebSocketClient(task: URLSession.shitheaden.webSocketTask(with: address))
        .connected()
    }
  }

  #if DEBUG

    public class ShitheadenSessionDelegate: NSObject, URLSessionDelegate {
      static let shared = ShitheadenSessionDelegate()

      public func urlSession(_: URLSession,
                             didReceive challenge: URLAuthenticationChallenge) async
        -> (URLSession.AuthChallengeDisposition, URLCredential?)
      {
        if challenge.protectionSpace.host.contains("192.168") {
          return (.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
        } else {
          return (.performDefaultHandling, nil)
        }
      }
    }

    public extension URLSession {
      static let shitheaden = URLSession(
        configuration: .default,
        delegate: ShitheadenSessionDelegate.shared,
        delegateQueue: OperationQueue()
      )
    }

  #else
    public extension URLSession {
      static let shitheaden = URLSession(
        configuration: .default,
        delegate: nil,
        delegateQueue: OperationQueue()
      )
    }
  #endif

#endif
