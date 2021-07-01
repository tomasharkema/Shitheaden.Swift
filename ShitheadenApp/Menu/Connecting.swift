//
//  Connecting.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 01/07/2021.
//

import Logging
import ShitheadenRuntime
import ShitheadenShared
import SwiftUI

@MainActor
class Connecting: ObservableObject {
  private let logger = Logger(label: "app.Connecting")
  private let websocket = WebSocketGameClient()
  private var client: WebSocketClient?
  @Published var connection: ConnectionState = .connecting

  private var identifier: UUID?
  private var code: String?
  private var name: String? = Storage.shared.name

  private var dataHandler: UUID?
  private var quitHandler: UUID?
  private var connectingTask: Task.Handle<Void, Error>?

  func start() async throws {
    connectingTask?.cancel()

    let connectingTask = async {
      connection = .connecting
      do {
        let client = try await websocket.start()
        logger.debug("CLIENT! \(String(describing: client))")
        self.client = client
        dataHandler = client.data.on {
          self.onData($0, client)
        }
        quitHandler = client.quit.on {
          self.connection = .gameNotFound
        }
      } catch {
        connection = .gameNotFound
        throw error
      }
    }

    self.connectingTask = connectingTask

    return try await connectingTask.get()
  }

  func close() {
    connectingTask?.cancel()
    async {
      await client?.close()
    }
  }

  var isInitiator: Bool = false
  private func onData(_ event: ServerEvent, _ client: WebSocketClient) {
    guard let name = name else {
      connection = .getName

      return
    }

    switch event {
    case .waiting:
      if let code = code {
        connection = .waiting(
          code: code,
          canStart: isInitiator,
          initiator: name,
          contestants: [],
          cpus: 0
        )
      }

    case let .error(error: .gameNotFound(code)):
      connection = .gameNotFound

    case let .error(error: error):
      logger.error("Received error: \(String(describing: error))")

    case .requestMultiplayerChoice:
      connection = .makeChoice

    case let .multiplayerEvent(.gameSnapshot(snapshot)):
      connection = .gameSnapshot(snapshot, client)

    case let .multiplayerEvent(multiplayerEvent: multiplayerEvent):
      logger.info("MultiplayerEvent: \(String(describing: multiplayerEvent))")

    case let .joined(initiator, contestants, cpus):
      if let code = code {
        connection = .waiting(
          code: code,
          canStart: contestants.count + cpus + 1 >= 2 && isInitiator,
          initiator: initiator,
          contestants: contestants,
          cpus: cpus
        )
      }

    case let .codeCreate(code: code):
      isInitiator = true
      self.code = code
      connection = .codeCreated(code: code)

    case .start:
      logger.info("START!")
    case .quit:
      connection = .gameNotFound

    case .requestSignature:
      break

    case let .signatureCheck(succeeded):
      logger.notice("SIGNATURE SUCCEEDED! \(succeeded)")

    case .requestRestart:
      connection = .restart(canStart: true)

    case .waitForRestart:
      connection = .restart(canStart: false)
    }
  }

  func connect(code: String) async throws { guard let name = name else {
    connection = .getName

    return
  }
  self.code = code
  try await client?.write(.joinMultiplayer(name: name, code: code))
  }

  func connect() async throws { guard let name = name else {
    connection = .getName

    return
  }
  try await client?.write(.startMultiplayer(name: name))
  }

  func addCpu() async throws {
    try await client?
      .write(.multiplayerRequest(.string("cpu+")))
  }

  func removeCpu() async throws {
    try await client?
      .write(.multiplayerRequest(.string("cpu-")))
  }

  func startGame() async throws {
    try await client?.write(.multiplayerRequest(.string("start")))
  }

  func set(name: String) {
    self.name = name
  }
}
