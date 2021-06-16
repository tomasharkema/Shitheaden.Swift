//
//  Symbol.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

enum Symbol: CaseIterable {
  case ruiten
  case schoppen
  case klaver
  case harten

  var color: Color {
    switch self {
    case .klaver, .schoppen:
      return .Black
    case .ruiten, .harten:
      return .Red
    }
  }

  var string: String {
    switch self {
    case .ruiten:
      return "♦"
    case .schoppen:
      return "♠"
    case .klaver:
      return "♣"
    case .harten:
      return "♥"
    }
  }
}
