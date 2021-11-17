//
//  MenuView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import Logging
import SwiftUI
import ShitheadenShared
import ShitheadenRuntime
import AsyncAwaitHelpers

class SnapshotHolder: ObservableObject {

  @Published var snapshot: GameSnapshot?

  func start() async {
    Task.detached(priority: .userInitiated) {
      assertNotMainQueue()
      let snap = await Persistence.getSnapshot()
      await MainActor.run {
        self.snapshot = snap
      }
    }
  }
}

struct MenuView: View {
  private let logger = Logger(label: "app.MenuView")

  @ObservedObject var snapshotHolder = SnapshotHolder()
  @Binding var state: AppState?
  @State var showAlert: Bool = false
  @State var joinCode: String = ""
  @State var settingsOverlay = false

  var body: some View {
    VStack(spacing: 20) {
      Text("💩").font(.system(size: 100))
      Text("Shitheaden").font(.system(size: 50, design: .rounded))

      ScrollView {
        HStack {
          Spacer()
          VStack(spacing: 20) {
            Spacer()

            if let snapshot = snapshotHolder.snapshot {
              Button("Speel verder", action: {
                withAnimation {
                  state = .resume(snapshot: snapshot)
                }
              })
            }

            Button("Single Player 4p", action: {
              withAnimation {
                state = .singlePlayer(contestants: 3)
              }
            })
            Button("Single Player 3p", action: {
              withAnimation {
                state = .singlePlayer(contestants: 2)
              }
            })
            Button("Single Player 2p", action: {
              withAnimation {
                state = .singlePlayer(contestants: 1)
              }
            })
            Button("Multiplayer Start", action: {
              withAnimation {
                state = .multiplayerChallenger
              }
            })
            Button("Multiplayer Join", action: {
//        withAnimation {
//          state = .multiplayerChallenger
//        }
              showAlert = true
            })
            Button("Uitleg", action: {
              withAnimation {
                state = .multiplayerChallenger
              }
            })
            Button("Instellingen", action: {
              withAnimation {
                settingsOverlay = true
              }
            })

            Spacer()
          }
          .sheet(isPresented: $settingsOverlay, onDismiss: nil, content: {
            SettingsView()
          })
          .background {
            if showAlert {
              AlertControlView(
                textString: $joinCode,
                showAlert: $showAlert,
                title: "Join code",
                message: ""
              )
            }
          }
          .onChange(of: joinCode, perform: { code in
            logger.info("joincode: \(code)")

            if code.count > 1 {
              state = .multiplayerJoin(code)
            }
          })
          .buttonStyle(.bordered)
          .controlSize(.large)
          Spacer()
        }
      }
    }.task {
      await snapshotHolder.start()
    }
  }
}
