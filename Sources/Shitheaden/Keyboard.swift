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
    let keyboard = FileHandle.standardInput
    async let inputData = keyboard.availableData
    let strData = await String(data: inputData, encoding: .utf8)!

    return strData.trimmingCharacters(in: .newlines)
  }
}
