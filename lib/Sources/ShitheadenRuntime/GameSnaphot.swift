//
//  GameSnaphot.swift
//
//
//  Created by Tomas Harkema on 18/06/2021.
//

import Foundation
import ShitheadenShared

public struct GameSnaphot: Equatable, Codable {
  public let numberOfDeckCards: Int
  public let players: [ObscuredPlayerResult]
  public let latestTableCards: [Card]
  public let numberOfTableCards: Int
  public let numberOfBurntCards: Int
  public let playerOnTurn: UUID
  public let winner: ObscuredPlayerResult?
}
