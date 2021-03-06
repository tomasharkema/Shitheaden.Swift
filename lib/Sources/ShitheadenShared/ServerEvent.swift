//
//  ServerEvent.swift
//
//
//  Created by Tomas Harkema on 21/06/2021.
//

import Foundation

public enum ServerError: LocalizedError, Equatable, Codable {
  case text(text: String)
  case playerError(error: PlayerError)

  case gameNotFound(code: String)

  public var errorDescription: String? {
    switch self {
    case let .text(text):
      return text
    case let .playerError(error):
      return error.errorDescription
    case let .gameNotFound(code):
      return "\(code) is niet gevonden"
    }
  }
}

public enum ServerEvent: Equatable, Codable {
  case error(error: ServerError)
  case requestMultiplayerChoice
  case multiplayerEvent(multiplayerEvent: MultiplayerEvent)
  case joined(initiator: String, contestants: [String], cpus: Int)
  case codeCreate(code: String)
  case signatureCheck(Bool)
  case requestRestart
  case waitForRestart

  case start
  case waiting
  case quit(from: UUID)
  case requestSignature

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
  case requestNormalTurn(canPass: Bool)
}

public enum ServerRequest: Equatable, Codable {
  case startMultiplayer(name: String)
  case joinMultiplayer(name: String, code: String)
  case multiplayerRequest(MultiplayerRequest)
  case startGame
  case quit(from: UUID)
  case singlePlayer
  case signature(String)

  public func getMultiplayerRequest() throws -> MultiplayerRequest {
    switch self {
    case .quit:
      throw PlayerError.unknown
    case let .multiplayerRequest(req):
      return req
    default:
      throw PlayerError.unknown
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
