//
//  ConnectionState.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 01/07/2021.
//

import Logging
import ShitheadenRuntime
import ShitheadenShared
import SwiftUI

enum ConnectionState {
  case getName
  case connecting
  case makeChoice
  case waiting(code: String, canStart: Bool, initiator: String, contestants: [String], cpus: Int)
  case gameNotFound
  case error(Error)
  case codeCreated(code: String)
//  case gameSnapshot(GameSnapshot)
  case gameContainer(GameContainer)
  case restart(canStart: Bool)
}
