//
//  ConnectingView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import ShitheadenRuntime
import ShitheadenShared
import SwiftUI

enum ConnectionState {
  case connecting
  case makeChoice
  case waiting(users: Int)
  case gameNotFound
  case codeCreated(String)
  case gameSnapshot(GameSnapshot, WebSocketHandler)
}

@MainActor
class Connecting: ObservableObject {
  let websocket = WebSocketClient()
  @Published var connection: ConnectionState = .connecting

  func start() {
    print("START")
    async {
      do {
        websocket.setOnConnected { connection in
          print("setOnConnected")

          connection.onQuit.append {
            self.connection = .gameNotFound
          }

          connection.onData.append { d in
            async {
              await MainActor.run {
                self.onData(d)
              }
            }
          }
        }

        try await websocket.start()
      } catch {
        print(error)
      }
    }
  }

  private func onData(_ event: ServerEvent) {
    switch event {
    case .waiting:
      connection = .waiting(users: 1)

    case let .error(error: .gameNotFound(code)):
      connection = .gameNotFound

    case let .error(error: error):
      print(error)
    case .requestMultiplayerChoice:
      connection = .makeChoice

    case let .multiplayerEvent(.gameSnapshot(snapshot)):
      connection = .gameSnapshot(snapshot, websocket.connection!)

    case let .multiplayerEvent(multiplayerEvent: multiplayerEvent):
      print(event)
    case let .joined(numberOfPlayers: numberOfPlayers):

      connection = .waiting(users: numberOfPlayers)

    case let .codeCreate(code: code):
      connection = .codeCreated(code)
    case .start:
      print(event)

    case .quit:
      connection = .gameNotFound
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
              await self.connection.websocket.connection?.write(.quit)
            }
          }

      case .connecting:
        VStack {
          Text("CONNECTING")
            .onAppear {
              connection.start()
            }
          Button("Opnieuw proberen") {
            connection.start()
          }
        }

      case .makeChoice:
        VStack {
          Text("CONNECTED!")
          Text("Finding game...")
            .onAppear {
              async {
                if let code = code {
                  await self.connection.websocket.connection?.write(.joinMultiplayer(code: code))
                } else {
                  await self.connection.websocket.connection?.write(.startMultiplayer)
                }
              }
            }
          Button("Opnieuw proberen") {
            self.connection.start()
          }
        }

      case let .waiting(int):
        Text("\(int) waiting to start")
        Button("Start!") {
          async {
            await self.connection.websocket.connection?.write(.multiplayerRequest(.string("start")))
          }
        }

      case let .codeCreated(code):
        Text("Je code is \(code)... Wachten tot er mensen joinen!")

      case .gameNotFound:
        Button("Spel niet gevonden. Ga terug") {
          state = nil
        }.onAppear {
          state = nil
        }
      }
      if case .gameSnapshot = connection.connection { } else {
        Button("Cancel", action: {
          state = nil
        })
      }
    }
  }
}
