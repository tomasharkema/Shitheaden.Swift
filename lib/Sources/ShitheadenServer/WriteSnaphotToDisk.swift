//
//  File.swift
//
//
//  Created by Tomas Harkema on 29/06/2021.
//

import Foundation
import ShitheadenRuntime
import ShitheadenShared

class WriteSnapshotToDisk {
  static func write(snapshot: EndGameSnapshot) async throws {
    let isCorrectlySigned = try await Signature.getSignature() == snapshot.signature

    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(
        "\(isCorrectlySigned ? "UNSIGNED-" : "")game-\(snapshot.gameId)-\(Int(snapshot.snapshot.beginDate))-\(snapshot.signature)-server.json"
      )

    let data = try JSONEncoder().encode(snapshot)
    try data
      .write(to: url)
  }
}
