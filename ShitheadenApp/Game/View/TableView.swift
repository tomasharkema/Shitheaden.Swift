//
//  TableView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import ShitheadenShared
import SwiftUI

struct TableView: View {
  let tableCards: [RenderCard]

  var body: some View {
    CardStackView(cards: .init(Array(tableCards.reversed())), offset: 15).zIndex(15)
//    CardStackView(cards: .init(max(0, numberOfTableCards - latestTableCards.count)), offset: 1)
//      .offset(x: 75, y: -75).zIndex(10)
  }
}
