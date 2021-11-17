//
//  EventHandler.swift
//
//
//  Created by Tomas Harkema on 23/06/2021.
//

import Foundation
import ShitheadenShared
import AsyncAwaitHelpers

public class EventHandler<T> {
  var events = [T]()
  var dataHandlers = DictionaryActor<UUID, (T) async -> Void>()

  public init() {}

  public func removeOnDataHandler(for identifier: UUID?) {
    if let identifier = identifier {
      Task {
        await dataHandlers.insert(identifier, value: nil)
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
      Task {
        await handler(element)
      }
    }

    events = []

    let uuid = UUID()

    Task {
      await dataHandlers.insert(uuid, value: handler)
    }
    return uuid
  }

  public func emit(_ value: T) {
    Task {
      if await dataHandlers.isEmpty() {
        events.append(value)
      }
      await dataHandlers.values().forEach { handler in
        Task {
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

    var function: ((Result<T, Error>) -> Void) = { _ in
      assertionFailure("FUNCTION NOT SET!")
    }
    await once { event in
      function(.success(event))
    }

    return try await withTaskCancellationHandler(handler: { [function] in
      function(.failure(NSError(domain: "", code: 0, userInfo: nil)))
    }, operation: {
      try await withCheckedThrowingContinuation { cont in
        function = {
          cont.resume(with: $0)
        }
      }
    })
  }

  public func map<N>(_ fn: @escaping (T) -> N) -> EventHandler<N>.ReadOnly {
    let eventHandler = EventHandler<N>()
    _ = on {
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

    public func removeOnDataHandler(for identifier: UUID?) {
      event.removeOnDataHandler(for: identifier)
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
