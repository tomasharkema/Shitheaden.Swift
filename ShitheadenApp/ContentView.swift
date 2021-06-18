//
//  ContentView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 18/06/2021.
//

import CustomAlgo
import Foundation
import ShitheadenRuntime
import ShitheadenShared
import SwiftUI

enum Orientation {
  case horizontal
  case vertical
}

enum RenderCard: Equatable, Hashable {
  case hidden
  case card(Card)

  init(_ card: Card) {
    self = .card(card)
  }

  var card: Card? {
    switch self {
    case .card(let card):
      return card
    case .hidden:
      return nil
    }
  }
}

struct ContentView: View {
  @StateObject var game = GameContainer()

  @ViewBuilder
  func card(_ card: RenderCard) -> some View {
    VStack {
      if let card = card.card {
        HStack {
  //      Text(card.symbol.string)
        Spacer()
          Text(card.number.string)
            .font(.subheadline.monospaced())
        }
        Text(card.symbol.string).font(.title3)
      } else {
        Text("💩")
      }
    }
    .shadow(radius: 2)
    .foregroundColor(card.card?.symbol == .harten || card.card?.symbol == .ruiten ? Color.red : Color.black)
    .padding(5)
    .frame(width: 40, height: 50)
    .background(Color.white)
    .cornerRadius(5)
    .id(card.hashValue)
    .shadow(radius: 2)
    .padding(3)
    .drawingGroup()
//    .transition(.identity)
  }

  @ViewBuilder
  func cards(count: Int, orientation: Orientation) -> some View {
    switch orientation {
    case .horizontal:
      HStack {
        ForEach(0..<count) { c in
          card(.hidden).id("closedh\(c)")
        }.id("closedh\(count)")
      }
    case .vertical:
      VStack {
        ForEach(0..<count) { c in
          card(.hidden).id("closedv\(c)")
        }.id("closedv\(count)")
      }
    }
  }

  @ViewBuilder
  func cards(cards: [Card], orientation: Orientation) -> some View {
    switch orientation {
    case .horizontal:
      HStack {
        ForEach(cards) { c in
          card(RenderCard(c))
        }
      }
    case .vertical:

      VStack {
        ForEach(cards) { c in
          card(RenderCard(c))
        }
      }
    }
  }

  @ViewBuilder
  func playerView(player: TurnRequest, orientation: Orientation) -> some View {
    if !player.done {
    VStack {
//      Text("\(player.name) (\(player.handCards.count))").font(.title3.bold().smallCaps())

      switch orientation {
      case .horizontal:
        VStack {
          cards(cards: player.openTableCards, orientation: orientation)
          cards(count: player.numberOfClosedTableCards, orientation: orientation)
            .foregroundColor(.white)
        }
      case .vertical:
        HStack {
          cards(cards: player.openTableCards, orientation: orientation)
          cards(count: player.numberOfClosedTableCards, orientation: orientation)
            .foregroundColor(.white)
        }
      }

    }.padding()
      .background(player.id == game.gameSnaphot?.playerOnTurn ? Color.green.opacity(1) : Color.green
        .opacity(0.3)).cornerRadius(5)
    }}

  @ViewBuilder
  func table(snapshot: GameSnaphot) -> some View {
    let d = Array(snapshot.table.suffix(5).reversed())
    stack(cards: d, offset: 15)
  }

  @ViewBuilder
  func stack(cards: [Card], offset: CGFloat, alignment: Alignment = Alignment.center) -> some View {
    ZStack(alignment: alignment) {
      ForEach(Array(cards.enumerated()), id: \.element) { el in
        card(RenderCard(el.element))
          .offset(x: CGFloat(el.offset) * offset, y: CGFloat(-el.offset) * offset)
          .zIndex(Double(10 - el.offset))
      }
    }
  }

  @ViewBuilder
  func stack(count: Int, offset: CGFloat, alignment: Alignment = Alignment.center) -> some View {
    ZStack(alignment: alignment) {
      ForEach(0..<count) { el in
        card(.hidden)
          .offset(x: CGFloat(el) * offset, y: CGFloat(-el) * offset)
          .zIndex(Double(10 - el))
      }
      .id("stack:count\(count)alignment:\(alignment)")
    }
  }

  @ViewBuilder
  func localPlayer() -> some View {
    VStack {
      if let error = game.error {
        Text(error).bold().foregroundColor(Color.red)
      }

      HStack {
        ScrollView(.horizontal) {
          HStack {
            ForEach(game.localCards) { c in
              StatedButton(action: { selected in
                game.select(c, selected: selected, deleteNotSameNumber: game.moveHandler != nil)
              }, label: {
                card(RenderCard(c))
              }, isSelected: game.selectedCards.contains(c))
            }
          }.padding()
        }

        Spacer()
        if game.isOnSet {
        if game.selectedCards.count > 0 {
          Button(action: {
            game.play()
          }, label: {
            Text("SPEEL!")
          })
        } else if game.canPass {
          Button(action: {
            game.play()
          }, label: {
            Text("PAS!")
          })
        }
        }
      }

    }.padding().background(Color.white)
  }

  @ViewBuilder
  func game(snapshot: GameSnaphot) -> some View {
    VStack {
    VStack {
      playerView(
        player: snapshot.players.first { $0.position == .noord }!,
        orientation: .horizontal
      )
      Spacer()
      HStack {
        playerView(player: snapshot.players.first { $0.position == .west }!, orientation: .vertical)
        Spacer()

        Spacer()

        playerView(player: snapshot.players.first { $0.position == .oost }!, orientation: .vertical)
      }
      Spacer()

      Spacer()
      playerView(player: snapshot.players.first { $0.position == .zuid }!, orientation: .horizontal)
    }
    .padding()
    .background(Color.blue).overlay(
      table(snapshot: snapshot) // .padding(20).background(Color.green).cornerRadius(10)
    )
    .overlay(stack(count: snapshot.deck.cards.count, offset: 2, alignment: Alignment.topLeading).padding(), alignment: Alignment.topLeading)
    .overlay(
      stack(count: snapshot.burnt.count, offset: 2, alignment: Alignment.topTrailing).padding(),
      alignment: Alignment.topTrailing)
    localPlayer()
    }
  }

  var body: some View {
    VStack {
      if let snapshot = game.gameSnaphot {
        game(snapshot: snapshot)
          .transition(.move(edge: .top))
          .animation(.linear, value: snapshot)
      }
    }
    #if os(iOS)
    .task {
      await game.start()
    }
    #else
    .onAppear {
      async {
        await game.start()
      }
    }
    #endif
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}

extension Player: Identifiable {}

extension Card: Identifiable {
  public var id: Int {
    hashValue
  }
}

struct StatedButton<Label>: View where Label: View {
  private let action: ((Bool) -> Void)?

  private let label: (() -> Label)?
  let isSelected: Bool

  init(action: ((Bool) -> Void)? = nil, label: (() -> Label)? = nil, isSelected: Bool) {
    self.action = action
    self.label = label
    self.isSelected = isSelected
  }

  var body: some View {
    Button(action: {
//      self.isSelected = !self.isSelected
      self.action?(!self.isSelected)
      print("isSelected now is \(!self.isSelected ? "true" : "false")")
    }) {
      label?()
        .overlay(Rectangle().foregroundColor(.clear)
                        .border(isSelected ? Color.green : Color.clear, width: 5).cornerRadius(10))
        .animation(.linear, value: isSelected)
    }
  }
}

extension Card: CustomStringConvertible {
  public var description: String {
    return "\(symbol.string)\(number.string)"
  }
}
