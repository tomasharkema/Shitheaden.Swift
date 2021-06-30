//
//  ConnectingView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import Logging
import ShitheadenRuntime
import ShitheadenShared
import SwiftUI

enum ConnectionState {
  case connecting
  case makeChoice
  case waiting(canStart: Bool, users: Int)
  case gameNotFound
  case codeCreated(String)
  case gameSnapshot(GameSnapshot, WebSocketClient)
  case restart(canStart: Bool)
}

@MainActor
class Connecting: ObservableObject {
  private let logger = Logger(label: "app.Connecting")
  private let websocket = WebSocketGameClient()
  public private(set) var client: WebSocketClient?
  @Published var connection: ConnectionState = .connecting

  var id: UUID?

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
    switch event {
    case .waiting:
      connection = .waiting(canStart: isInitiator, users: 1)

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

    case let .joined(numberOfPlayers: numberOfPlayers):
      connection = .waiting(canStart: numberOfPlayers >= 2 && isInitiator, users: numberOfPlayers)

    case let .codeCreate(code: code):
      isInitiator = true
      connection = .codeCreated(code)

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
}

struct ConnectingView: View {
  @Binding var state: AppState?
  @StateObject var connection = Connecting()
  let code: String?

  var body: some View {
    VStack {
      switch connection.connection {
      case let .gameSnapshot(snapshot, handler):
        GameView(state: $state, gameType: .online(handler))
          .onDisappear {
            async {
              await handler.close()
            }
          }

      case .connecting:
        VStack {
          Text("CONNECTING")
            .onAppear {
              async {
                try await connection.start()
              }
            }
          Button("Opnieuw proberen") {
            async {
              try await connection.start()
            }
          }.buttonStyle(.bordered)
        }

      case let .restart(canStart):
        VStack {
          Text("Nog een spelletje?")
          Text("Finding game...")
            .onAppear {
              async {
                if let code = code {
                  try await self.connection.client?
                    .write(.joinMultiplayer(code: code))
                } else {
                  try await self.connection.client?.write(.startMultiplayer)
                }
              }
            }
          if canStart {
            Button("Opnieuw proberen") {
              async {
                try await self.connection.start()
              }
            }.buttonStyle(.bordered)
          }
        }

      case .makeChoice:
        VStack {
          Text("CONNECTED!")
          Text("Finding game...")
            .onAppear {
              async {
                if let code = code {
                  try await self.connection.client?
                    .write(.joinMultiplayer(code: code))
                } else {
                  try await self.connection.client?.write(.startMultiplayer)
                }
              }
            }
          Button("Opnieuw proberen") {
            async {
              try await self.connection.start()
            }
          }.buttonStyle(.bordered)
        }

      case let .waiting(canStart, int):
        VStack {
        Text("\(int) waiting to start")
        if canStart {
          Button("Add cpu!") {
            async {
              try await self.connection.client?
                .write(.multiplayerRequest(.string("cpu")))
            }
          }.buttonStyle(.bordered)
          Button("Start!") {
            async {
              try await self.connection.client?
                .write(.multiplayerRequest(.string("start")))
            }
          }.buttonStyle(.bordered)
        }
        }
      case let .codeCreated(code):
        Text("Je code is \(code)... Wachten tot er mensen joinen!")
        Button("Add cpu!") {
          async {
            try await self.connection.client?
              .write(.multiplayerRequest(.string("cpu")))
          }
        }.buttonStyle(.bordered)

      case .gameNotFound:
        Button("Spel niet gevonden. Ga terug") {
          state = nil
        }.buttonStyle(.bordered)
          .onAppear {
            state = nil
          }
      }
      if case .gameSnapshot = connection.connection { } else {
        Button("Annuleren", action: {
          connection.close()
          state = nil
        }).buttonStyle(.bordered)
      }
    }
  }
}
