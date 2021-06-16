//
//  CustomAlgo.swift
//  
//
//  Created by Tomas Harkema on 15/06/2021.
//

import ShitheadenShared

public actor CustomAlgo: GameAi {
  public required init() {}

  public func move(request: TurnRequest) async -> Turn {
    return .pass
  }
}
