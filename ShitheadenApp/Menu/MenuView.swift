//
//  MenuView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import Logging
import SwiftUI

struct MenuView: View {
  private let logger = Logger(label: "app.MenuView")

  @Binding var state: AppState?
  @State var showAlert: Bool = false
  @State var joinCode: String = ""

  var body: some View {
    VStack(spacing: 10) {
      Text("💩").font(.system(size: 100))
      Button("Single Player 4p", action: {
        withAnimation {
          state = .singlePlayer(contestants: 3)
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

      if showAlert {
        AlertControlView(
          textString: $joinCode,
          showAlert: $showAlert,
          title: "Join code",
          message: ""
        )
      }
    }.onChange(of: joinCode, perform: { code in
      logger.info("joincode: \(code)")

      if code.count > 1 {
        state = .multiplayerJoin(code)
      }
    }).buttonStyle(.bordered)
      .controlSize(.large).controlProminence(.increased)
  }
}
