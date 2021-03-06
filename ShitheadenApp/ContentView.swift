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
  case singlePlayer(contestants: Int)
  case multiplayerChallenger
  case multiplayerJoin(String)
  case resume(snapshot: GameSnapshot)
}

struct ContentView: View {
  @State var appState: AppState?

  @StateObject var offlineGame = GameContainer()

  var body: some View {
    switch appState {
    case let .singlePlayer(contestants):
      GameView(state: $appState, game: offlineGame)
        .task {

              await offlineGame.start(restart: true, contestants: contestants)
        }


    case .resume(let snapshot):
      GameView(state: $appState, game: offlineGame)
        .task {
              await offlineGame.resume(snapshot: snapshot)
        }



    case .multiplayerChallenger:
      ConnectingView(state: $appState, code: nil)


    case let .multiplayerJoin(code):
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

extension Card: Identifiable {}

extension Card: CustomStringConvertible {
  public var description: String {
    "\(symbol.string)\(number.string)"
  }
}
