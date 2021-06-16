//
//  Ai.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

protocol PlayerMove {
  static var algoName: String { get }

  init()

  func move(player: Player, table: Table) async -> Turn
}
