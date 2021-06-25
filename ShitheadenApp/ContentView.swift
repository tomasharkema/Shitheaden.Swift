//
//  ContentView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 18/06/2021.
//

import CustomAlgo
import Foundation
import ShitheadenRuntime
import ShitheadenShared
import SwiftUI

enum AppState {
  case singlePlayer
  case multiplayerChallenger
  case multiplayerJoin(String)
}

struct ContentView: View {
  @State var appState: AppState?

  var body: some View {
    switch appState {
    case .singlePlayer:
      GameView(state: $appState, gameType: .offline)
    case .multiplayerChallenger:
//        GameView(state: $appState)
      ConnectingView(state: $appState, code: nil)
    case let .multiplayerJoin(code):
//        GameView(state: $appState, gameType: .offline)
      ConnectingView(state: $appState, code: code)
    case .none:
      MenuView(state: $appState)
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}

// extension Player: Identifiable {}

extension Card: Identifiable {}

extension Card: CustomStringConvertible {
  public var description: String {
    "\(symbol.string)\(number.string)"
  }
}
