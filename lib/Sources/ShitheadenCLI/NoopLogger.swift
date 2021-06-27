//
//  NoopLogger.swift
//
//
//  Created by Tomas Harkema on 26/06/2021.
//

import Logging

struct NoopLogger: LogHandler {
  subscript(metadataKey _: String) -> Logger.Metadata.Value? {
    get {
      nil
    }
    set(newValue) {}
  }

  var metadata: Logger.Metadata = [:]

  var logLevel: Logger.Level = .error
}
