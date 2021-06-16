//
//  Rules.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

struct Rules: OptionSet {
  let rawValue: Int
  static let againAfterPass = Rules(rawValue: 1 << 0)
  static let againAfterGoodBehavior = Rules(rawValue: 1 << 1)
  static let all = Rules(rawValue: Int.max)
}
