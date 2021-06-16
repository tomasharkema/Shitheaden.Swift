//
//  File.swift
//  
//
//  Created by Tomas Harkema on 15/06/2021.
//

import ShitheadenShared

public actor PassBot: GameAi {
  public required init() {}

  public func move(request: TurnRequest) async -> Turn {
    return .pass
  }
}
