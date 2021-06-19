//
//  Keyboard.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Foundation
import ShitheadenRuntime

class Keyboard {
  static func getKeyboardInput() async -> String {
    // let keyboard = FileHandle.standardInput
    let inputData = readLine()
    guard let line = inputData else {
      return ""
    }
    print("READ: '\(line)'")
    return line.trimmingCharacters(in: .newlines)
  }
}
