//
//  Extensions.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

extension Array {
//  mutating func shuffle() {
//    for i in 0..<(count - 1) {
//      let j = Int(arc4random_uniform(UInt32(count - i))) + i
//      swap(&self[i], &self[j])
//    }
//  }

//  func without(index: Int) -> [Element] {
//    var newArray = [Element]()
//    newArray = self
//    newArray.remove(at: index)
//    return newArray
//  }
}

// extension Array where Element: Equatable {
//  mutating func remove(el: Element) {
//    self = filter { (element: Element) -> Bool in
//      el != element
//    }
//  }
//
//  func without(el: Element) -> [Element] {
//    var newArray = self
//
//    if let index = newArray.firstIndex(of: el) {
//      newArray.remove(at: index)
//    }
//    return newArray
//  }
//
//  func without(el: [Element]) -> [Element] {
//    var newArray = self
//
//    for e in el {
//      newArray = newArray.without(el: e)
//    }
//
//    return newArray
//  }
// }
//
// extension Array where Element: Hashable {
//  func without(el: Set<Element>) -> [Element] {
//    var newArray = self
//
//    for e in el {
//      newArray.remove(el: e)
//    }
//
//    return newArray
//  }
// }
//
// extension Set where Element: Equatable {
//  func without(el: Element) -> Set<Element> {
//    var newArray = Set<Element>()
//
//    for obj in self {
//      if el != obj {
//        newArray.insert(obj)
//      }
//    }
//
//    return newArray
//  }
// }

//
//
// extension Int {
//  static func random(range: Range<Int> ) -> Int {
//    var offset = 0
//
//    if range.startIndex < 0   // allow negative ranges
//    {
//      offset = abs(range.startIndex)
//    }
//
//    let mini = UInt32(range.startIndex + offset)
//    let maxi = UInt32(range.endIndex   + offset)
//
//    return Int(mini + arc4random_uniform(maxi - mini)) - offset
//  }
// }

extension String {
  func print() {
    Swift.print(self)
  }
}
