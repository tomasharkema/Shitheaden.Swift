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
import Foundation

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
          async {
            Storage.shared.name = name
            self.connection.set(name: name)
            if let code = code {
              try await self.connection.connect(code: code)
            } else {
              try await self.connection.connect()
            }
          }
        }.disabled(name.isEmpty).buttonStyle(.bordered)

//      case let .gameSnapshot(snapshot, handler):
      case let .gameContainer(container):
        GameView(state: $state, game: container)
//        GameView(state: $state, gameType: .online(handler))
//          .onDisappear {
//            handler.close()
//          }

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
                  try await self.connection.connect(code: code)
                } else {
                  try await self.connection.connect()
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
                  try await self.connection.connect(code: code)
                } else {
                  try await self.connection.connect()
                }
              }
            }
          Button("Opnieuw proberen") {
            async {
              try await self.connection.start()
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
                async {
                  try await self.connection.addCpu()
                }
              }.buttonStyle(.bordered)
            }
            if contestants.count + cpus + 1 > 1 {
              Button("Remove cpu!") {
                async {
                  try await self.connection.removeCpu()
                }
              }.buttonStyle(.bordered)
            }
            Button("Start!") {
              async {
                try await self.connection.startGame()
              }
            }.buttonStyle(.bordered)
          }
        }

      case let .codeCreated(code):
        Text("Je code is \(code)... Wachten tot er mensen joinen!")
        Button("Add cpu!") {
          async {
            try await self.connection.addCpu()
          }
        }.buttonStyle(.bordered)

      case .error(let error):
        Text(error.localizedDescription)

      case .gameNotFound:
        Button("Spel niet gevonden. Ga terug") {
          state = nil
        }.buttonStyle(.bordered)
          .onAppear {
            state = nil
          }
      }
      if case .gameContainer = connection.connection { } else {
        Button("Annuleren", action: {
          connection.close()
          state = nil
        }).buttonStyle(.bordered)
      }
    }
  }
}

extension String: Identifiable {
  public var id: Self {
    self
  }
}
