//
//  GameSnaphot.swift
//
//
//  Created by Tomas Harkema on 18/06/2021.
//

import Foundation

public struct GameSnapshot: Equatable, Codable {
  public let deckCards: [RenderCard]
  public let players: [TurnRequest]
  public let tableCards: [RenderCard]
  public let burntCards: [RenderCard]
  public let playersOnTurn: Set<UUID>
  public let requestFor: UUID?
  public let currentRequest: TurnRequest?

  public init(
    deckCards: [RenderCard],
    players: [TurnRequest],
    tableCards: [RenderCard],
    burntCards: [RenderCard],
    playersOnTurn: Set<UUID>,
    requestFor: UUID?
  ) {
    self.deckCards = deckCards
    self.players = players
    self.tableCards = tableCards
    self.burntCards = burntCards
    self.playersOnTurn = playersOnTurn
    self.requestFor = requestFor

    currentRequest = requestFor != nil ? players.first { $0.id == requestFor } : nil
  }

  public var winner: TurnRequest? {
    return players.first { $0.endState == .winner }
  }
}
