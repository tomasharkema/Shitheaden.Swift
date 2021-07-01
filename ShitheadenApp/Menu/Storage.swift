//
//  Storage.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 01/07/2021.
//

import SwiftUI

@MainActor
class Storage: ObservableObject {
  static let shared = Storage()

  @AppStorage("name")
  var name: String?
}
