//
//  Ai.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public protocol GameAi: Actor {
//  init()

  static func make() -> GameAi

  func render(snapshot: GameSnapshot) async throws
  func beginMove(request: TurnRequest, snapshot: GameSnapshot) async throws
    -> (Card, Card, Card)
  func move(request: TurnRequest, snapshot: GameSnapshot) async throws -> Turn
}

public extension GameAi {
  nonisolated var algoName: String {
    String(describing: self)
  }

  nonisolated static var algoName: String {
    String(describing: Self.self)
  }
}
