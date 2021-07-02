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

  public func once(initial _: Bool = false, _ handler: @escaping (T) async -> Void) async {
    let uuid = UUID()
    var hasSend = false
    let function = { (element: T) in
      if !hasSend {
        hasSend = true
        await handler(element)
        await self.dataHandlers.insert(uuid, value: nil)
      }
    }

    await dataHandlers.insert(uuid, value: function)
  }

  public func on(_ handler: @escaping (T) async -> Void) -> UUID {
    events.forEach { element in
      async {
        await handler(element)
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
        async {
          await handler(value)
        }
      }
    }
  }

  public func once(initial: Bool = true) async throws -> T {
    if let last = events.last, initial {
      events = []
      return last
    }

    var function: ((Result<T, Error>) -> Void)!
    await once { event in
      function(.success(event))
    }

    return try await withTaskCancellationHandler(operation: {
      try await withUnsafeThrowingContinuation { cont in
        function = {
          cont.resume(with: $0)
        }
      }
    }, onCancel: { [function] in
      function!(.failure(NSError(domain: "", code: 0, userInfo: nil)))
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

    public func once(initial: Bool = false, _ fn: @escaping (T) -> Void) async {
      await event.once(initial: initial, fn)
    }

    public func once(initial: Bool = true) async throws -> T {
      try await event.once(initial: initial)
    }

    public func on(_ fn: @escaping (T) async -> Void) -> UUID {
      event.on(fn)
    }

    public func map<N>(_ fn: @escaping (T) -> N) -> EventHandler<N>.ReadOnly {
      event.map(fn)
    }
  }
}
