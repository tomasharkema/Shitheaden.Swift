//
//  Persistence.swift
//  
//
//  Created by Tomas Harkema on 18/10/2021.
//

import Foundation
import Logging
import ShitheadenShared
import AsyncAwaitHelpers

public class Persistence {
  private static let logger = Logger(label: "runtime.Persistence")

  private static func homePath() -> URL {
    let homePath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(
        "shitheaden"
      )

    if !FileManager.default.fileExists(atPath: homePath.path) {
      do {
      try FileManager.default.createDirectory(at: homePath, withIntermediateDirectories: false, attributes: nil)

    } catch {
      logger.error("error: \(error)")
      return homePath
    }
    }

    return homePath
  }

  private static func snapshotPath() -> URL { homePath().appendingPathComponent("snapshot.json")
  }

  static private var task: Task<Void, Never>?

  static func saveSnapshot(snapshot: GameSnapshot, priority: TaskPriority = .background) async {
    self.task?.cancel()
    let task = Task.detached(priority: priority) {
      do {
        try Task.checkCancellation()
        let json = try JSONEncoder().encode(snapshot)
        try Task.checkCancellation()
        let path = snapshotPath()
        try Task.checkCancellation()
        logger.info("Writing json to \(path.absoluteString)")

        try Task.checkCancellation()
        try json.write(to: path, options: [.atomic])
        try Task.checkCancellation()

        logger.info("WRITE SUCCEEDED!")
      } catch {
        logger.error("ERROR: \(error)")
      }
    }
    self.task = task
    await task.value
  }

  static func invalidateSnapshot() {
    Task.detached(priority: .background) {
      assertNotMainQueue()
      do {
        try FileManager.default.removeItem(at: snapshotPath())
      } catch {
        logger.error("Removal failed \(error)")
      }
    }
  }

  static public func getSnapshot() async -> GameSnapshot? {
    do {
      let path = snapshotPath()

      if !FileManager.default.fileExists(atPath: path.path) {
        logger.info("File does not exist")
        return nil
      }

      async let data = try Data(contentsOf: path)
      assert(!Thread.isMainThread)
      return  try await JSONDecoder().decode(GameSnapshot.self, from: data)

    } catch {
      logger.error("Error: \(error)")
      return nil
    }
  }
}
