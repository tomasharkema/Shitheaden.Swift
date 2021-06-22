//
//  CardStackView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import ShitheadenShared
import SwiftUI

struct CardStackView: View {
  let cards: [RenderCard]
  let offset: CGFloat
  let alignment = Alignment.center

  var body: some View {
    let d = Array(cards)
    ZStack(alignment: alignment) {
      ForEach(Array(d.enumerated()), id: \.element) { el in
        CardView(card: el.element)
          .offset(x: CGFloat(el.offset) * offset, y: CGFloat(-el.offset) * offset)
          .zIndex(Double(10 - el.offset))
      }
    }
  }
}

// extension EnumeratedSequence where Base == Array<RenderCard> {
//  var id: String {
//
//  }
// }
