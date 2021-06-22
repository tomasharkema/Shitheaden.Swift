//
//  Ai.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public protocol GameAi: Actor {
  init()

  func render(snapshot: GameSnapshot, error: PlayerError?) async -> Void
  func beginMove(request: TurnRequest, previousError: PlayerError?) async throws
    -> (Card, Card, Card)
  func move(request: TurnRequest, previousError: PlayerError?) async throws -> Turn
}

public extension GameAi {
  nonisolated var algoName: String {
    String(describing: self)
  }

  nonisolated static var algoName: String {
    String(describing: Self.self)
  }
}
