//
//  ConnectingView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import Foundation
import Logging
import ShitheadenRuntime
import ShitheadenShared
import SwiftUI

struct ConnectingView: View {
  @State var name: String = ""
  @Binding var state: AppState?
  @StateObject var connection = Connecting()
  let code: String?

  var body: some View {
    VStack {
      switch connection.connection {
      case .getName:
        Text("Wat is je naam?")
        TextField("Naam", text: $name).padding()
        Button("Verder") {
          Task {
            Storage.shared.name = name
            self.connection.set(name: name)
            if let code = code {
              await self.connection.connect(code: code)
            } else {
              await self.connection.connect()
            }
          }
        }.disabled(name.isEmpty).buttonStyle(.bordered)

      case .gameContainer:
        GameView(state: $state, game: connection.gameContainer)

      case .connecting:
        VStack {
          Text("CONNECTING")
            .task {
              await connection.start()
            }
          Button("Opnieuw proberen") {
            Task {
              await connection.start()
            }
          }.buttonStyle(.bordered)
        }

      case let .restart(canStart):
        VStack {
          Text("Nog een spelletje?")
          Text("Finding game...")
            .task {
                if let code = code {
                  await self.connection.connect(code: code)
                } else {
                  await self.connection.connect()
                }
            }
          if canStart {
            Button("Opnieuw proberen") {
              Task {
                await self.connection.start()
              }
            }.buttonStyle(.bordered)
          }
        }

      case .makeChoice:
        VStack {
          Text("CONNECTED!")
          Text("Finding game...")
            .task {
                if let code = code {
                  await self.connection.connect(code: code)
                } else {
                  await self.connection.connect()
                }
            }
          Button("Opnieuw proberen") {
            Task {
              await self.connection.start()
            }
          }.buttonStyle(.bordered)
        }

      case let .waiting(code, canStart, initiator, contestants, cpus):
        VStack {
          Text("Spel van \(initiator)")
          Text("Je code is \(code)... cpus: \(cpus)")
          HStack {
            ForEach(contestants) { contestant in
              Text(contestant)
            }
          }

          if canStart {
            if contestants.count + cpus + 1 < 4 {
              Button("Add cpu!") {
                Task {
                  try await self.connection.addCpu()
                }
              }.buttonStyle(.bordered)
            }
            if contestants.count + cpus + 1 > 1 {
              Button("Remove cpu!") {
                Task {
                  try await self.connection.removeCpu()
                }
              }.buttonStyle(.bordered)
            }
            Button("Start!") {
              Task {
                try await self.connection.startGame()
              }
            }.buttonStyle(.bordered)
          }
        }

      case let .codeCreated(code):
        Text("Je code is \(code)... Wachten tot er mensen joinen!")
        Button("Add cpu!") {
          Task {
            try await self.connection.addCpu()
          }
        }.buttonStyle(.bordered)

      case let .error(error):
        Text(error.localizedDescription)

      case .gameNotFound:
        Button("Spel niet gevonden. Ga terug") {
          state = nil
        }
        .buttonStyle(.bordered)
      }
      if case .gameContainer = connection.connection { } else {
        Button("Annuleren", action: {
          connection.close()
          state = nil
        })
        .buttonStyle(.bordered)
      }
    }
  }
}

extension String: Identifiable {
  public var id: Self {
    self
  }
}
