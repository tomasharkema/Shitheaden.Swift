//
//  File.swift
//
//
//  Created by Tomas Harkema on 15/06/2021.
//

import Foundation

public enum Position: CaseIterable {
  case noord
  case oost
  case zuid
  case west
}

public struct TurnRequest: Equatable {
  public let id: UUID
  public let name: String
  public let handCards: [Card]
  public let openTableCards: [Card]
  public let lastTableCard: Card?
  public let numberOfClosedTableCards: Int
  public let phase: Phase
  public let amountOfTableCards: Int
  public let amountOfDeckCards: Int
  public let algoName: String
  public let done: Bool
  public let position: Position

  public init(id: UUID, name: String,
              handCards: [Card],
              openTableCards: [Card],
              lastTableCard: Card?,
              numberOfClosedTableCards: Int,
              phase: Phase,
              amountOfTableCards: Int,
              amountOfDeckCards: Int,
              algoName: String,
              done: Bool, position: Position)
  {
    self.id = id
    self.name = name
    self.handCards = handCards
    self.openTableCards = openTableCards
    self.lastTableCard = lastTableCard
    self.numberOfClosedTableCards = numberOfClosedTableCards
    self.phase = phase
    self.amountOfTableCards = amountOfTableCards
    self.amountOfDeckCards = amountOfDeckCards
    self.algoName = algoName
    self.done = done
    self.position = position
  }
}
