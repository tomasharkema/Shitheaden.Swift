//
//  Phase.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

public enum Phase: Codable, Hashable {
  case hand
  case tableOpen
  case tableClosed

  public var isTableOpen: Bool {
    switch self {
    case .tableOpen:
      return true
    default:
      return false
    }
  }
}
