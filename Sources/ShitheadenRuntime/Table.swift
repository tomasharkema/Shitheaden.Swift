//
//  File.swift
//
//
//  Created by Tomas Harkema on 16/06/2021.
//

import ShitheadenShared

public typealias Table = [Card]

extension Table {
  var lastCard: Card? {
    return lazy.filter { $0.number != .three }.last
  }
}
