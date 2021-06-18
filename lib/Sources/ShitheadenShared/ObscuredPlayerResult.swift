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
    case .player(let player):
      return player
    case .obscured:
      return nil
    }
  }

  public var obscured: ObsucredTurnRequest? {
    switch self {
    case .player:
      return nil
    case .obscured(let obscured):
      return obscured
    }
  }

  public var done: Bool {
    switch self {
    case .player(let player):
      return player.done
    case .obscured(let obscured):
      return obscured.done
    }
  }

  public var position: Position {
    switch self {
    case .player(let player):
      return player.position
    case .obscured(let obscured):
      return obscured.position
    }
  }

  public var name: String {
    switch self {
    case .player(let turnRequest):
      return turnRequest.name
    case .obscured(let obsucredTurnRequest):
      return obsucredTurnRequest.name
    }
  }

  public var numberOfHandCards: Int {
    switch self {
    case .player(let turnRequest):
      return turnRequest.handCards.count
    case .obscured(let obsucredTurnRequest):
      return obsucredTurnRequest.numberOfHandCards
    }
  }

  public var numberOfClosedTableCards: Int {
    switch self {
    case .player(let turnRequest):
      return turnRequest.numberOfClosedTableCards
    case .obscured(let obsucredTurnRequest):
      return obsucredTurnRequest.numberOfClosedTableCards
    }
  }

  public var algoName: String {
    switch self {
    case .player(let turnRequest):
      return turnRequest.algoName
    case .obscured(let obsucredTurnRequest):
      return obsucredTurnRequest.algoName
    }
  }

  public var openTableCards: [Card] {
    switch self {
    case .player(let turnRequest):
      return turnRequest.openTableCards
    case .obscured(let obsucredTurnRequest):
      return obsucredTurnRequest.openTableCards
    }
  }

  public var id: UUID {
    switch self {
    case .player(let turnRequest):
      return turnRequest.id
    case .obscured(let obsucredTurnRequest):
      return obsucredTurnRequest.id
    }
  }
}
