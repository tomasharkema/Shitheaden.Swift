//
//  File.swift
//
//
//  Created by Tomas Harkema on 15/06/2021.
//

import Foundation

public struct TurnRequest: Equatable, Codable {
  public let id: UUID
  public let name: String
  public let handCards: [RenderCard]
  public let openTableCards: [RenderCard]
  public let lastTableCard: Card?
  public let closedCards: [RenderCard]
  public let phase: Phase
  public let tableCards: [RenderCard]
  public let deckCards: [RenderCard]
  public let algoName: String
  public let done: Bool
  public var position: Position
  public let isObscured: Bool
  public let playerError: PlayerError?
  public let endState: EndPlace?

  public init(
    id: UUID, name: String,
    handCards: [RenderCard],
    openTableCards: [RenderCard],
    lastTableCard: Card?,
    closedCards: [RenderCard],
    phase: Phase,
    tableCards: [RenderCard],
    deckCards: [RenderCard],
    algoName: String,
    done: Bool,
    position: Position,
    isObscured: Bool,
    playerError: PlayerError?, endState: EndPlace?
  ) {
    self.id = id
    self.name = name
    self.handCards = handCards
    self.openTableCards = openTableCards
    self.lastTableCard = lastTableCard
    self.closedCards = closedCards
    self.phase = phase
    self.tableCards = tableCards
    self.deckCards = deckCards
    self.algoName = algoName
    self.done = done
    self.position = position
    self.isObscured = isObscured
    self.playerError = playerError
    self.endState = endState
  }
}
