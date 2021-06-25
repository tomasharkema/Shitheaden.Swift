//
//  ShitheadenAppApp.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 18/06/2021.
//

import Logging
import LoggingOSLog
import SwiftUI

@main
struct ShitheadenAppApp: App {
  init() {
    LoggingSystem.bootstrap(LoggingOSLog.init)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
