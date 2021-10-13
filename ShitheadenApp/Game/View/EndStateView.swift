//
//  EndStateView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 24/06/2021.
//

import ShitheadenShared
import SwiftUI

struct EndStateView: View {
  let endState: EndPlace?
  let restart: () async -> Void
  let quit: () async -> Void

  var body: some View {
    if let endState = endState {
      ZStack {
        Spacer()
        VStack {
          switch endState {
          case .winner:
            Text("Je hebt gewonnen!").font(.title)
          case let .place(int):
            Text("Je bent \(int)e geworden...").font(.title)
          }
          if #available(iOS 15.0, *) {
            Button("Nog een spelletje") {
              async {
                await restart()
              }
            }.buttonStyle(.bordered)

            Button("Stoppen") { async {
              await quit()
            }
            }.buttonStyle(.bordered).tint(Color.red)
          }
        }
        .padding()
        .background(Color.green)
        .cornerRadius(20)
        .overlay(
          RoundedRectangle(cornerRadius: 20)
            .stroke(Color.green, lineWidth: 5)
        )
        .padding()
      }
      .background(Color.black.opacity(0.3))
    }
  }
}

struct EndStateView_Previews: PreviewProvider {
  static var previews: some View {
    EndStateView(endState: .winner, restart: {}, quit: {})
  }
}
