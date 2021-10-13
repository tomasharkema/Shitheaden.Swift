//
//  Storage.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 01/07/2021.
//

import ShitheadenShared
import SwiftUI

@MainActor
class Storage: ObservableObject {
  static let shared = Storage()

  @AppStorage("name")
  var name: String?

  @AppStorage(wrappedValue: Rules.all, "rules")
  var rules: Rules

//  var rules: Binding<Rules> {
//    Binding(get: {
//      Rules(rawValue: self.rulesRaw)
//    }, set: {
//      self.rulesRaw = $0.rawValue
//    })
//  }
}
