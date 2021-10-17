//
//  EqualsIgnoringOrderTests.swift
//  
//
//  Created by Tomas Harkema on 17/10/2021.
//

@testable import ShitheadenShared
import XCTest

class EqualsIgnoringOrderTests: XCTestCase {
  func testEqualsIgnoringOrder_CorrectOrder() {

    let first = UUID()
    let second = UUID()
    let third = UUID()

    let left = [
      Card(id: first, symbol: .schoppen, number: .seven),
      Card(id: second, symbol: .klaver, number: .seven),
      Card(id: third, symbol: .harten, number: .seven),
    ]

    let right = [
      Card(id: first, symbol: .schoppen, number: .seven),
      Card(id: second, symbol: .klaver, number: .seven),
      Card(id: third, symbol: .harten, number: .seven),
    ]

    XCTAssertTrue(left.equalsIgnoringOrder(as: right))
  }

  func testEqualsIgnoringOrder_IncorrectOrder() {

    let first = UUID()
    let second = UUID()
    let third = UUID()

    let left = [
      Card(id: first, symbol: .schoppen, number: .seven),
      Card(id: second, symbol: .klaver, number: .seven),
      Card(id: third, symbol: .harten, number: .seven),
    ]

    let right = [
      Card(id: first, symbol: .schoppen, number: .seven),
      Card(id: third, symbol: .harten, number: .seven),
      Card(id: second, symbol: .klaver, number: .seven),
    ]

    XCTAssertTrue(left.equalsIgnoringOrder(as: right))
  }
}
