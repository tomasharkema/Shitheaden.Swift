//
//  CardView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import ShitheadenShared
import SwiftUI

struct CardView: View {
  let card: RenderCard

  var body: some View {
    VStack {
      if let card = card.card {
        HStack {
          //      Text(card.symbol.string)
          Spacer()
          Text(card.number.string)
            .foregroundColor(card.numberColor)
            .font(.subheadline.monospaced().bold())
        }
        Text(card.symbol.string).font(.title3)
      } else {
        Text("💩")
      }
    }
    .shadow(radius: 2)
    .foregroundColor(card.card?.color)
    .padding(5)
    .frame(width: 40, height: 50)
    .background(Color.white)
    .cornerRadius(5)
    .id(card.hashValue)
    .shadow(radius: 2)
    .padding(3)
    .drawingGroup()
    .id("CARD\(card.id.uuidString)")
    //    .transition(.identity)
  }
}

struct CardView_Previews: PreviewProvider {
  static var previews: some View {
    LazyVGrid(columns: [
      GridItem(.adaptive(minimum: 40, maximum: 40)),
    ]) {
      CardView(card: .hidden(id: UUID()))
      ForEach(Number.allCases, id: \.string) { number in
        ForEach(Symbol.allCases, id: \.string) { symbol in
          CardView(card: .card(card: .init(id: .init(), symbol: symbol, number: number)))
        }
      }
    }.padding()
  }
}

extension Card {
  var color: Color {
    switch symbol {
    case .harten, .ruiten:
      return Color.red
    case .klaver, .schoppen:
      return Color.black
    }
  }

  var numberColor: Color {
    switch number {
    case .gold:
      return Color.yellow
    case .silver:
      return Color.gray
    case .bronze:
      return Color.orange
    default:
      return color
    }
  }
}

extension RenderCard: Identifiable {
  public var id: UUID {
    switch self {
    case let .card(card):
      return card.id
    case let .hidden(hidden):
      return hidden
    }
  }
}
