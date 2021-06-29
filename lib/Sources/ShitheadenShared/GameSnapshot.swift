//
//  GameSnaphot.swift
//
//
//  Created by Tomas Harkema on 18/06/2021.
//

import Foundation

public struct UserAndTurn: Equatable, Codable {
  public let uuid: String
  public let turn: Turn
  public init(uuid: String, turn: Turn) {
    self.uuid = uuid
    self.turn = turn
  }
}

public struct GameSnapshot: Equatable, Codable {
  public let deckCards: [RenderCard]
  public let players: [TurnRequest]
  public let tableCards: [RenderCard]
  public let burntCards: [RenderCard]
  public let playersOnTurn: Set<UUID>
  public let requestFor: UUID?
  public let currentRequest: TurnRequest?
  public let beginDate: TimeInterval
  public let endDate: TimeInterval?
  public let turns: [UserAndTurn]?
  public init(
    deckCards: [RenderCard],
    players: [TurnRequest],
    tableCards: [RenderCard],
    burntCards: [RenderCard],
    playersOnTurn: Set<UUID>,
    requestFor: UUID?, beginDate: TimeInterval, endDate: TimeInterval?,
    turns: [UserAndTurn]?
  ) {
    self.deckCards = deckCards
    self.players = players
    self.tableCards = tableCards
    self.burntCards = burntCards
    self.playersOnTurn = playersOnTurn
    self.requestFor = requestFor
    self.beginDate = beginDate
    self.endDate = endDate
    self.turns = turns
    currentRequest = requestFor != nil ? players.first { $0.id == requestFor } : nil
  }

  public var winner: TurnRequest? {
    players.first { $0.endState == .winner }
  }
}
