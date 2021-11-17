//
//  ShitheadenApp.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 18/06/2021.
//

import Logging
import LoggingOSLog
import SwiftUI

@main
struct ShitheadenApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .onAppear {
          LoggingSystem.bootstrap(LoggingOSLog.init)
        }
    }
  }
}
