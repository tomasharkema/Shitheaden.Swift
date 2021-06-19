//
//  Event.swift
//
//
//  Created by Tomas Harkema on 19/06/2021.
//

import ShitheadenRuntime

enum ServerError: Equatable, Codable {
  case text(String)
}

enum Event: Equatable, Codable {
  case error(ServerError)
  case action(Action)
  case render(GameSnaphot)
}

enum Action: Equatable, Codable {
  case requestTurn
}
