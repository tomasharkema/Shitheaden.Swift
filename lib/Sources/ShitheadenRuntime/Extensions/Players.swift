//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import Foundation
import ShitheadenShared

extension Array where Element == Player {
  mutating func sortPlayerLowestCard() {
    let lowest = min { left, right in
      let lFilter = left.handCards.filter { $0.number >= .four }
      let rFilter = right.handCards.filter { $0.number >= .four }

      let lMin = lFilter.min() ?? Card(id: .init(), symbol: .harten, number: .aas)
      let rMin = rFilter.min() ?? Card(id: .init(), symbol: .harten, number: .aas)

      if lMin == rMin {
        let lCount = left.handCards.filter { $0.number == lMin.number }.count
        let rCount = right.handCards.filter { $0.number == rMin.number }.count
        return lCount < rCount
      }

      return lMin < rMin
    }

    guard let player = lowest, let place = firstIndex(of: player) else {
      return
    }
    self = shifted(by: -place)
  }
}
