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

  public func once(_ handler: @escaping (T) async -> Void) {
    let uuid = UUID()
    var hasSend = false
    let function = { (element: T) in
      if !hasSend {
        hasSend = true
        await handler(element)
      }
    }
    DispatchQueue.global().async {
      async {
        await self.dataHandlers.insert(uuid, value: function)
      }
    }
  }

  public func on(_ handler: @escaping (T) async -> Void) -> UUID {
    events.forEach { element in
      DispatchQueue.global().async {
        async {
          await handler(element)
        }
      }
    }

    events = []

    let uuid = UUID()

    async {
      await dataHandlers.insert(uuid, value: handler)
    }
    return uuid
  }

  public func emit(_ value: T) {
    async {
      if await dataHandlers.isEmpty() {
        events.append(value)
      }
      await dataHandlers.values().forEach { handler in
        DispatchQueue.global().async {
          async {
            await handler(value)
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
    }, operation: {
      try await withUnsafeThrowingContinuation { cont in
        handler.once { _ in
          cont.resume(throwing: PlayerError.debug("QUIT"))
        }
        self.once { event in
          cont.resume(returning: event)
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
    ReadOnly(event: self)
  }

  class ReadOnly {
    private let event: EventHandler<T>

    init(event: EventHandler<T>) {
      self.event = event
    }

    public func removeOnDataHandler(id: UUID?) {
      event.removeOnDataHandler(id: id)
    }

    public func once(_ fn: @escaping (T) -> Void) {
      event.once(fn)
    }

    public func once() async throws -> T {
      try await event.once()
    }

    public func on(_ fn: @escaping (T) async -> Void) -> UUID {
      event.on(fn)
    }

    public func map<N>(_ fn: @escaping (T) -> N) -> EventHandler<N>.ReadOnly {
      event.map(fn)
    }
  }
}
