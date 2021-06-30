//
//  File.swift
//
//
//  Created by Tomas Harkema on 29/06/2021.
//

import Foundation

public enum Host {
  #if DEBUG
    public static let host = URL(string: "https://192.168.1.76:3338")!
  #else
    public static let host = URL(string: "https://shitheaden-api.harke.ma")!
  #endif
}
