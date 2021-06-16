//
//  Keyboard.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Foundation

class Keyboard {
  static func getKeyboardInput() async -> String {
    let keyboard = FileHandle.standardInput
    async let inputData = keyboard.availableData
    let strData = await String(data: inputData, encoding: .utf8)!

    return strData.trimmingCharacters(in: .newlines)
  }

  static func getKeuzeFromInput(input: String) -> [Int]? {
    let inputs = input.split(separator: ",").map {
      Int($0.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    if inputs.contains(nil) {
      Position.input.down(n: 1) >>> "Je moet p of een aantal cijfers invullen..."
      return nil
    }

    return inputs.map { $0! }
  }
}
