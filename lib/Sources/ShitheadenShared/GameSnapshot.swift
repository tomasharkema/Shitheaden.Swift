//
//  GameSnaphot.swift
//
//
//  Created by Tomas Harkema on 18/06/2021.
//

import Foundation

public struct GameSnapshot: Equatable, Codable {
  public let numberOfDeckCards: Int
  public let players: [ObscuredPlayerResult]
  public let latestTableCards: [Card]
  public let numberOfTableCards: Int
  public let numberOfBurntCards: Int
  public let playerOnTurn: UUID
  public let winner: ObscuredPlayerResult?

  public init(
    numberOfDeckCards: Int, players: [ObscuredPlayerResult], latestTableCards: [Card], numberOfTableCards: Int, numberOfBurntCards: Int, playerOnTurn: UUID, winner: ObscuredPlayerResult?) {
    self.numberOfDeckCards = numberOfDeckCards
    self.players = players
    self.latestTableCards = latestTableCards
    self.numberOfTableCards = numberOfTableCards
    self.numberOfBurntCards = numberOfBurntCards
    self.playerOnTurn = playerOnTurn
    self.winner = winner
  }
}
