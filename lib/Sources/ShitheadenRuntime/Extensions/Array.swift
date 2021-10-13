//
//  File.swift
//
//
//  Created by Tomas Harkema on 16/06/2021.
//

extension Array {
  func shifted(by shiftAmount: Int) -> [Element] {
    // 1
    guard count > 0, (shiftAmount % count) != 0 else { return self }

    // 2
    let moduloShiftAmount = shiftAmount % count
    let negativeShift = shiftAmount < 0
    let effectiveShiftAmount = negativeShift ?
      moduloShiftAmount + count : moduloShiftAmount

    // 3
    let shift: (Int)
      -> Int = {
        $0 + effectiveShiftAmount >= self.count ? $0 + effectiveShiftAmount - self
          .count : $0 + effectiveShiftAmount
      }

    // 4
    return enumerated().sorted(by: { shift($0.offset) < shift($1.offset) }).map(\.element)
  }
}

extension Array where Element: Comparable {
  func equalsIgnoringOrder(as other: [Element]) -> Bool {
    if self == other {
      return true
    } else {
      return count == other.count && sorted() == other.sorted()
    }
  }
}
