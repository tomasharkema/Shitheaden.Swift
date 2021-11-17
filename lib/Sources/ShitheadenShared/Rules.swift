//
//  Rules.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public struct Rules: OptionSet, Codable, Hashable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let againAfterPass = Rules(rawValue: 1 << 0)
  public static let againAfterPlayingFourCards = Rules(rawValue: 1 << 1)
  public static let getCardWhenPassOpenCardTables = Rules(rawValue: 1 << 2)
  public static let unfairPassingAllowed = Rules(rawValue: 1 << 3)

  public static let all = Rules(rawValue: Int.max)
  public static let shitheaden: Rules = [.unfairPassingAllowed]
}
