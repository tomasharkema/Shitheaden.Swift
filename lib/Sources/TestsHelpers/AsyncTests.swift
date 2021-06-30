//
//  AsyncTests.swift
//
//
//  Created by Tomas Harkema on 30/06/2021.
//

import Foundation
import XCTest

public extension XCTestCase {
  func asyncTest(
    timeout: TimeInterval,
    _ handler: @escaping () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let expectation = XCTestExpectation(description: "asyncTest")

    if #available(macOS 9999, iOS 9999, *) {
      async {
        do {
          await try handler()
        } catch {
          XCTFail("ERROR: \(error)", file: file, line: line)
        }
        expectation.fulfill()
      }
    }
    wait(for: [expectation], timeout: timeout)
  }
}
