//
//  Event.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

import ShitheadenRuntime
import ShitheadenShared

enum ServerError: Equatable, Codable {
  case text(String)
  case playerError(PlayerError)
}

enum Event: Equatable, Codable {
  case error(ServerError)
  case action(Action)
  case render(GameSnapshot)
}

enum Action: Equatable, Codable {
  case requestTurn
}
