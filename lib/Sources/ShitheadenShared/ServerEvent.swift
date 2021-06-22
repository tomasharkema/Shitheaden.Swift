//
//  ServerEvent.swift
//
//
//  Created by Tomas Harkema on 21/06/2021.
//

import Foundation

public enum ServerError: Equatable, Codable {
  case text(text: String)
  case playerError(error: PlayerError)

  case gameNotFound(code: String)
}

public enum ServerEvent: Equatable, Codable {
  case error(error: ServerError)
  case requestMultiplayerChoice
  case multiplayerEvent(multiplayerEvent: MultiplayerEvent)
  case joined(numberOfPlayers: Int)
  case codeCreate(code: String)

  case start
  case waiting
  case quit

  public func getMultiplayerEvent() throws -> MultiplayerEvent {
    switch self {
    case let .multiplayerEvent(req):
      return req
    default:
      throw NSError(domain: "", code: 0, userInfo: nil)
    }
  }
}

public enum MultiplayerEvent: Equatable, Codable {
  case error(error: PlayerError)

  case action(action: Action)

  case string(string: String)
  case gameSnapshot(snapshot: GameSnapshot)
}

public enum Action: Equatable, Codable {
  case requestBeginTurn
  case requestNormalTurn
}

public enum ServerRequest: Equatable, Codable {
  case startMultiplayer
  case joinMultiplayer(code: String)
  case multiplayerRequest(MultiplayerRequest)
  case startGame
  case quit
  case singlePlayer

  public func getMultiplayerRequest() throws -> MultiplayerRequest {
    switch self {
    case let .multiplayerRequest(req):
      return req
    default:
      throw NSError(domain: "", code: 0, userInfo: nil)
    }
  }
}

public enum MultiplayerRequest: Equatable, Codable {
  case cardIndexes([Int])
  case concreteCards([Card])
  case concreteTurn(Turn)
  case string(String)
  case pass

  public var string: String? {
    switch self {
    case let .string(string):
      return string
    default:
      return nil
    }
  }
}
