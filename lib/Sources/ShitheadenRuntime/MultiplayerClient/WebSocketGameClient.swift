//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//
#if !os(Linux)
  import Foundation
  import ShitheadenShared

  public class WebSocketGameClient {
    private let address =
      URL(
        string: "\(Host.host.absoluteString.replacingOccurrences(of: "http", with: "ws"))/websocket"
      )!

    public init() {}

    public func start() async throws -> WebSocketClient {
      try await WebSocketClient(task: URLSession.shared.webSocketTask(with: address))
        .connected()
    }
  }
#endif
