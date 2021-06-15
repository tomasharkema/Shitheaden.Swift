//
//  PlayerError.swift
//
//
//  Created by Tomas Harkema on 15/06/2021.
//

public struct PlayerError: Error {
  public  let text: String

  public init(text: String) {
    self.text = text
  }

  public var errorDescription: String? {
    text
  }
}
