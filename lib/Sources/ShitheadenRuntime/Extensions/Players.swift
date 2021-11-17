//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import Foundation
import ShitheadenShared

extension Array where Element == Card {
  func lowestCard() -> Element? {
    return self.min {
      $0.number < $1.number
    }
  }
}

extension Array where Element == Player {
  mutating func sortPlayerLowestCard() {
    let lowest = self.min { left, right in
      let lFilter = left.handCards.filter { $0.number >= .four }
      let rFilter = right.handCards.filter { $0.number >= .four }

      let lMin = lFilter.lowestCard() ?? Card(id: .init(), symbol: .harten, number: .aas)
      let rMin = rFilter.lowestCard() ?? Card(id: .init(), symbol: .harten, number: .aas)

      if lMin == rMin {
        let lCount = left.handCards.filter { $0.number == lMin.number }.count
        let rCount = right.handCards.filter { $0.number == rMin.number }.count
        return lCount < rCount
      }

      return lMin.number < rMin.number
    }

    guard let player = lowest, let place = firstIndex(of: player) else {
      return
    }
    self = shifted(by: -place)
  }
}
