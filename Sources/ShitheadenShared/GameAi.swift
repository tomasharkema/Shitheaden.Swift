//
//  Ai.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public protocol GameAi: Actor {
  init()

  func move(request: TurnRequest) async -> Turn
}

extension GameAi {
  public var algoName: String {
    String(describing: self)
  }

  public static var algoName: String {
    String(describing: Self.self)
  }
}
