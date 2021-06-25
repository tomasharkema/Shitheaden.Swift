//
//  File.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import Foundation
import ShitheadenShared

extension Array where Element == Player {
  func sortPlayerLowestCard() -> [Player] {
    let m = min { l, r in
      let lFilter = l.handCards.filter { $0.number >= .four }
      let rFilter = r.handCards.filter { $0.number >= .four }

      let lMin = lFilter.min() ?? Card(id: .init(), symbol: .harten, number: .aas)
      let rMin = rFilter.min() ?? Card(id: .init(), symbol: .harten, number: .aas)

      if lMin == rMin {
        let lCount = l.handCards.filter { $0.number == lMin.number }.count
        let rCount = r.handCards.filter { $0.number == rMin.number }.count
        return lCount < rCount
      }

      return lMin < rMin
    }

    guard let player = m, let place = firstIndex(of: player) else {
      return self
    }
    return shifted(by: -place)
  }
}
