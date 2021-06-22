//
//  MenuView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import SwiftUI

struct MenuView: View {
  @Binding var state: AppState?
  @State var showAlert: Bool = false
  @State var joinCode: String = ""

  var body: some View {
    VStack(spacing: 10) {
      Text("💩").font(.system(size: 100))
      Button("Single Player", action: {
        withAnimation {
          state = .singlePlayer
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
      print("\(code)")
      if code.count > 1 {
        state = .multiplayerJoin(code)
      }
    })
  }
}
