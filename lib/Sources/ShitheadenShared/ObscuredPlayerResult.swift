//
//  File.swift
//
//
//  Created by Tomas Harkema on 18/06/2021.
//

import Foundation

public enum ObscuredPlayerResult: Equatable, Codable {
  case player(TurnRequest)
  case obscured(ObsucredTurnRequest)

  public var player: TurnRequest? {
    switch self {
    case let .player(player):
      return player
    case .obscured:
      return nil
    }
  }

  public var obscured: ObsucredTurnRequest? {
    switch self {
    case .player:
      return nil
    case let .obscured(obscured):
      return obscured
    }
  }

  public var done: Bool {
    switch self {
    case let .player(player):
      return player.done
    case let .obscured(obscured):
      return obscured.done
    }
  }

  public var position: Position {
    switch self {
    case let .player(player):
      return player.position
    case let .obscured(obscured):
      return obscured.position
    }
  }

  public var name: String {
    switch self {
    case let .player(turnRequest):
      return turnRequest.name
    case let .obscured(obsucredTurnRequest):
      return obsucredTurnRequest.name
    }
  }

  public var numberOfHandCards: Int {
    switch self {
    case let .player(turnRequest):
      return turnRequest.handCards.count
    case let .obscured(obsucredTurnRequest):
      return obsucredTurnRequest.numberOfHandCards
    }
  }

  public var numberOfClosedTableCards: Int {
    switch self {
    case let .player(turnRequest):
      return turnRequest.numberOfClosedTableCards
    case let .obscured(obsucredTurnRequest):
      return obsucredTurnRequest.numberOfClosedTableCards
    }
  }

  public var algoName: String {
    switch self {
    case let .player(turnRequest):
      return turnRequest.algoName
    case let .obscured(obsucredTurnRequest):
      return obsucredTurnRequest.algoName
    }
  }

  public var openTableCards: [Card] {
    switch self {
    case let .player(turnRequest):
      return turnRequest.openTableCards
    case let .obscured(obsucredTurnRequest):
      return obsucredTurnRequest.openTableCards
    }
  }

  public var id: UUID {
    switch self {
    case let .player(turnRequest):
      return turnRequest.id
    case let .obscured(obsucredTurnRequest):
      return obsucredTurnRequest.id
    }
  }
}
