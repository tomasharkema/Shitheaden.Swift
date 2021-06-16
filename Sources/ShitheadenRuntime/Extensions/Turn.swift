//
//  File.swift
//
//
//  Created by Tomas Harkema on 16/06/2021.
//

import Foundation
import ShitheadenShared

extension Turn {
  var explain: String {
    switch self {
    case let .play(cards):
      #if os(Linux)
        let cardsJoined = "\(cards)"
      #else
        let cardsJoined = ListFormatter().string(from: Array(cards))!
      #endif
      return "\(cardsJoined) spelen"

    case .pass:
      return "Je kan niet passen..."

    case .closedCardIndex:
      return ""
    }
  }
}
