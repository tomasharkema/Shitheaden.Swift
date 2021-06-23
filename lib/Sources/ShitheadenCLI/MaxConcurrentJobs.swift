//
//  MaxConcurrentJobs.swift
//
//
//  Created by Tomas Harkema on 17/06/2021.
//

import Dispatch

class MaxConcurrentJobs {
  let spawn: Int
  let jobs: Jobs

  init(spawn: Int) {
    self.spawn = spawn
    jobs = Jobs(spawn: spawn)
  }

  func wait() async -> @Sendable () async -> Void {
    let fun: @Sendable () async -> Void = {
      print("========== CONTINUE FUN")
//      asyncDetached {
      await self.jobs.cont()
//      }
    }

    await print("========== START!!!!!!!!", jobs.current, spawn)

    if await jobs.hasPlace() {
      await print("========== CONTINUE", jobs.current, spawn)
      return fun
    }

    await print("========== WAIT", jobs.current, spawn)

    await withCheckedContinuation { r in
      DispatchQueue.global().async { // fix to not be needed?
        async {
          await self.jobs.insert(r: r)
        }
      }
    }

    await print("========== CONTINUE AFTER WAIT", jobs.current, spawn)
    return await wait()
  }
}

extension MaxConcurrentJobs {
  actor Jobs {
    let spawn: Int
    var current: Int = 0
    var tasks = [CheckedContinuation<Void, Never>]()

    init(spawn: Int) {
      self.spawn = spawn
    }

    func cont() {
      print("========== CONTINUE FUN OJOO \(current) \(tasks.count)")
      current -= 1
      print("========== CONTINUE FUN OJOO less \(current) \(tasks.count)")
      if let task = tasks.first {
        async {
          task.resume()
        }
        tasks.removeFirst()
      }
    }

    func hasPlace() -> Bool {
      print("HAS PLACE")
      if current < spawn {
        current += 1
        return true
      } else {
        return false
      }
    }

    func insert(r: CheckedContinuation<Void, Never>) {
      print("INSERT")
      tasks.append(r)
    }
  }
}
