//
//  MaxConcurrentJobs.swift
//
//
//  Created by Tomas Harkema on 17/06/2021.
//

import Dispatch
import Logging

class MaxConcurrentJobs {
  private let logger = Logger(label: "cli.MaxConcurrentJobs")

  let spawn: Int
  let jobs: Jobs

  init(spawn: Int) {
    self.spawn = spawn
    jobs = Jobs(spawn: spawn)
  }

  func wait() async -> @Sendable () async -> Void {
    let fun: @Sendable () async -> Void = {
      self.logger.notice("========== CONTINUE FUN")
      await self.jobs.cont()
    }

    let jobCurrent = await jobs.current
    let spawned = await spawn
    await logger.notice("========== START!!!!!!!!, \(jobCurrent), \(spawned)")

    if await jobs.hasPlace() {
      let jobCurrent = await jobs.current
      await logger.notice("========== CONTINUE, \(jobCurrent), \(spawn)")
      return fun
    }

    let jobCurrent3 = await jobs.current
    let spawned3 = await spawn
    await logger.notice("========== WAIT, \(jobCurrent3), \(spawned3)")

    await withCheckedContinuation { cont in
      DispatchQueue.global().async { // fix to not be needed?
        async {
          await self.jobs.insert(continuationTask: cont)
        }
      }
    }

    let jobCurrent2 = await jobs.current
    let s2 = await spawn
    await logger.notice("========== CONTINUE AFTER WAIT \(jobCurrent2), \(s2)")
    return await wait()
  }
}

extension MaxConcurrentJobs {
  actor Jobs {
    private let logger = Logger(label: "cli.MaxConcurrentJobs.Jobs")
    let spawn: Int
    var current: Int = 0
    var tasks = [CheckedContinuation<Void, Never>]()

    init(spawn: Int) {
      self.spawn = spawn
    }

    func cont() {
      logger.notice("========== CONTINUE FUN OJOO \(current) \(tasks.count)")
      current -= 1
      logger.notice("========== CONTINUE FUN OJOO less \(current) \(tasks.count)")
      if let task = tasks.first {
        task.resume()
        tasks.removeFirst()
      }
    }

    func hasPlace() -> Bool {
      logger.notice("HAS PLACE")
      if current < spawn {
        current += 1
        return true
      } else {
        return false
      }
    }

    func insert(continuationTask: CheckedContinuation<Void, Never>) {
      logger.notice("INSERT")
      tasks.append(continuationTask)
    }
  }
}
