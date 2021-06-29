//
//  Signature.swift
//
//
//  Created by Tomas Harkema on 29/06/2021.
//

import Foundation

public enum Signature {
  public static func getSignature() async throws -> String {
    guard let url = Bundle.main.url(forResource: "lib", withExtension: "sig") else {
      throw NSError(domain: "NO SIGNATURE!", code: 0, userInfo: nil)
    }
    print("URL \(url)") // swiftlint:disable:this disable_print
    async let string = try String(contentsOf: url)
      .replacingOccurrences(of: "  -\n", with: "")
    return try await string
  }
}
