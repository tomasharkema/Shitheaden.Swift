//
//  AtomicDictonary.swift
//  
//
//  Created by Tomas Harkema on 19/06/2021.
//

actor AtomicDictonary<Key: Hashable, Value> {
  var dict = [Key: Value]()

  public func insert(_ key: Key, value: Value) {
    dict[key] = value
  }

  public func get(_ key: Key) -> Value? {
    return dict[key]
  }
}
