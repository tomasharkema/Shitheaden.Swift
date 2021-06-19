//
//  Promise.swift
//  
//
//  Created by Tomas Harkema on 19/06/2021.
//

class Promise {
  private(set) var task: Task.Handle<Void, Never>!
  private var handler: UnsafeContinuation<Void, Never>!

  init() {
    task = async { await withUnsafeContinuation { g in
      self.handler = g
    }}
  }

  func resolve() {
    handler.resume()
  }
}
