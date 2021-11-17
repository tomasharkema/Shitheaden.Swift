//
//  Connecting.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 01/07/2021.
//

import Combine
import Logging
import ShitheadenRuntime
import ShitheadenShared
import SwiftUI

@MainActor
class Connecting: ObservableObject {
  private let logger = Logger(label: "app.Connecting")
  private let websocket = WebSocketGameClient()
  @Published private var client: WebSocketClient?
  @Published var connection: ConnectionState = .connecting
  @Published var lastError: Error?
  let gameContainer = GameContainer()

  private var identifier: UUID?
  private var code: String?
  private var name: String? = Storage.shared.name

  private var dataHandler: AnyCancellable?
  private var quitHandler: AnyCancellable?

  private var connectingTask: Task<Void, Never>?

  func start() async {
    connectingTask?.cancel()

    let connectingTask = Task {
      connection = .connecting
      do {
        let client = try await websocket.start()
        logger.debug("CLIENT! \(String(describing: client))")
        self.client = client
        dataHandler = client.$data
          .filter { $0 != nil }
          .receive(on: RunLoop.main)
          .sink { event in
            Task {
              await self.onData(event!, client)
            }
          }

        quitHandler = client.$quit.filter { $0 != nil }
          .receive(on: RunLoop.main)
          .sink { _ in
            self.connection = .gameNotFound
          }
      } catch {
        connection = .gameNotFound
        lastError = error
//        throw error
      }
    }

    self.connectingTask = connectingTask

    return await connectingTask.value
  }

  func close() {
    connectingTask?.cancel()
    client?.close()
  }

  var isInitiator: Bool = false
  private func onData(_ event: ServerEvent, _ client: WebSocketClient) async {
    await gameContainer.handleOnlineObject(
      event,
      client: client
    )

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

    case .error(error: .gameNotFound):
      connection = .gameNotFound

    case let .error(error: error):
      connection = .error(error)

    case .requestMultiplayerChoice:
      connection = .makeChoice

    case .multiplayerEvent(.gameSnapshot):
      if case .gameContainer = connection {
        // NO-OP
      } else {
        Task {
          await gameContainer.startOnline(client, restart: false)
        }
      }
      connection = .gameContainer(gameContainer)

    case .multiplayerEvent:
      break

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

  func connect(code: String) async {
    guard let name = name else {
      connection = .getName
      return
    }
    self.code = code
    do {
      _ = try await client?.write(.joinMultiplayer(name: name, code: code))
    } catch {
      lastError = error
    }
  }

  func connect() async {
    guard let name = name else {
      connection = .getName

      return
    }
    do {
      _ = try await client?.write(.startMultiplayer(name: name))
    } catch {
      lastError = error
    }
  }

  func addCpu() async throws {
    _ = try await client?
      .write(.multiplayerRequest(.string("cpu+")))
  }

  func removeCpu() async throws {
    _ = try await client?
      .write(.multiplayerRequest(.string("cpu-")))
  }

  func startGame() async throws {
    _ = try await client?.write(.multiplayerRequest(.string("start")))
  }

  func set(name: String) {
    self.name = name
  }
}
