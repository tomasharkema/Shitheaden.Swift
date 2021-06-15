//
//  File.swift
//
//
//  Created by Tomas Harkema on 15/06/2021.
//

public struct TurnRequest {
  public let handCards: [Card]
  public let openTableCards: [Card]
  public let lastTableCard: Card?
  public let numberOfClosedTableCards: Int
  public let phase: Phase
  public let amountOfTableCards: Int
  public let amountOfDeckCards: Int

  public init(
    handCards: [Card],
    openTableCards: [Card],
    lastTableCard: Card?,
    numberOfClosedTableCards: Int,
    phase: Phase,
    amountOfTableCards: Int,
    amountOfDeckCards: Int
  ) {
    self.handCards = handCards
    self.openTableCards = openTableCards
    self.lastTableCard = lastTableCard
    self.numberOfClosedTableCards = numberOfClosedTableCards
    self.phase = phase
    self.amountOfTableCards = amountOfTableCards
    self.amountOfDeckCards = amountOfDeckCards
  }
}
