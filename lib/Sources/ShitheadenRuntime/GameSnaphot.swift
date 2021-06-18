//
//  GameSnaphot.swift
//
//
//  Created by Tomas Harkema on 18/06/2021.
//

import Foundation
import ShitheadenShared

public struct GameSnaphot: Equatable, Codable {
  public let deck: Deck
  public let players: [ObscuredPlayerResult]
  public let table: Table
  public let burnt: [Card]
  public let playerOnTurn: UUID
}
