//
//  EventHandler.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import Foundation
import ShitheadenShared

public class EventHandler<T> {
  var events = [T]()
  var dataHandlers = AtomicDictionary<UUID, (T) async -> Void>()

  public init() {}

  public func removeOnDataHandler(id: UUID?) {
    if let id = id {
      async {
        await dataHandlers.insert(id, value: nil)
      }
    }
  }

  public func once(_ fn: @escaping (T) async -> Void) {
    let uuid = UUID()
    var hasSend = false
    let f = { (el: T) in
      if !hasSend {
        hasSend = true
        await fn(el)
      }
    }
    DispatchQueue.global().async {
      async {
        await self.dataHandlers.insert(uuid, value: f)
      }
    }
  }

  public func on(_ fn: @escaping (T) async -> Void) -> UUID {
    events.forEach { el in
      DispatchQueue.global().async {
        async {
          await fn(el)
        }
      }
    }

    events = []

    let uuid = UUID()
    async {
      await dataHandlers.insert(uuid, value: fn)
    }
    return uuid
  }

  public func emit(_ v: T) {
    async {
      if await dataHandlers.isEmpty() {
        events.append(v)
      }
      await dataHandlers.values().forEach { fn in
        DispatchQueue.global().async {
          async {
            await fn(v)
          }
        }
      }
    }
  }

  public func once() async throws -> T {
    if let last = events.last {
      events = []
      return last
    }

    let handler = EventHandler<Void>()
    return try await withTaskCancellationHandler(handler: {
      handler.emit(())
      print("CANCEL!", handler)
    }, operation: {
      try await withUnsafeThrowingContinuation { g in
        print(" SET HANDLER!")
        handler.once { _ in
          g.resume(throwing: PlayerError.debug("QUIT"))
        }
        self.once { d in
          g.resume(returning: d)
        }
      }
    })
  }

  public func map<N>(_ fn: @escaping (T) -> N) -> EventHandler<N>.ReadOnly {
    let eventHandler = EventHandler<N>()
    on {
      eventHandler.emit(fn($0))
    }
    return eventHandler.readOnly
  }
}

public extension EventHandler {
  var readOnly: ReadOnly {
    return ReadOnly(e: self)
  }

  class ReadOnly {
    private let e: EventHandler<T>

    init(e: EventHandler<T>) {
      self.e = e
    }

    public func removeOnDataHandler(id: UUID?) {
      return e.removeOnDataHandler(id: id)
    }

    public func once(_ fn: @escaping (T) async -> Void) {
      return e.once(fn)
    }

    public func once() async throws -> T {
      return try await e.once()
    }

    public func on(_ fn: @escaping (T) async -> Void) -> UUID {
      return e.on(fn)
    }

    public func map<N>(_ fn: @escaping (T) -> N) -> EventHandler<N>.ReadOnly {
      return e.map(fn)
    }
  }
}
