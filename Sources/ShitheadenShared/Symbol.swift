//
//  Symbol.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public enum Symbol: CaseIterable {
  case ruiten
  case schoppen
  case klaver
  case harten

  public var string: String {
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
