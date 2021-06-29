//
//  EndGameSnapshot.swift
//
//
//  Created by Tomas Harkema on 29/06/2021.
//

import Foundation

public struct EndGameSnapshot: Codable {
  public let gameId: UUID
  public let snapshot: GameSnapshot
  public let signature: String

  public init(gameId: UUID, snapshot: GameSnapshot, signature: String) {
    self.gameId = gameId
    self.snapshot = snapshot
    self.signature = signature
  }
}
