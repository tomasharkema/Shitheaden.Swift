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
//  private let address = URL(string: "wss://shitheaden-api.harkema.io")!
  private let address = URL(string: "wss://shitheaden-api.harkema.io/websocket")!
//    private let address = URL(string: "ws://192.168.1.76:3338/websocket")!

  public init() {}

  public func start() async throws -> WebSocketClient {
    return try await WebSocketClient(task: URLSession.shared.webSocketTask(with: address)).connected()
  }
}
#endif
