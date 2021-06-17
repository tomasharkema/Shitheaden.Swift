//
//  MaxConcurrentJobs.swift
//
//
//  Created by Tomas Harkema on 17/06/2021.
//

class MaxConcurrentJobs {
  let spawn: Int
  let jobs: Jobs

  init(spawn: Int) {
    self.spawn = spawn
    self.jobs = Jobs(spawn: spawn)
  }

  func wait() async -> () -> Void {
    let fun: () -> Void = {
      print("========== CONTINUE FUN")
      asyncDetached {
        await self.jobs.cont()
      }
    }

    await print("========== START!!!!!!!!", jobs.current, spawn)


    if await jobs.hasPlace() {
      await print("========== CONTINUE", jobs.current, spawn)
      return fun
    }

    await print("========== WAIT", jobs.current, spawn)

    await withCheckedContinuation { r in
      asyncDetached {
        await self.jobs.insert(r: r)
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
    asyncDetached {
      task.resume()
    }
    tasks.removeFirst()
  }
}

    func hasPlace() -> Bool {
      if current < spawn {
        current += 1
        return true
      } else {
        return false
      }
    }

    func insert(r: CheckedContinuation<Void, Never>) {
      tasks.append(r)
    }
  }

}
