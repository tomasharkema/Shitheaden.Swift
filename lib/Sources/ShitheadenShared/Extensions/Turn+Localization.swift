//
//  File.swift
//
//
//  Created by Tomas Harkema on 16/06/2021.
//
#if !os(Linux)
  import Foundation
#endif

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
      return "passen"

    case .closedCardIndex:
      return ""
    }
  }
}
