//
//  GameView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import ShitheadenRuntime
import SwiftUI

//enum GameType {
//  case offline
//  case online(WebSocketClient)
//}

struct GameView: View {
  @Binding var state: AppState?
//  let gameType: GameType
  @State var showMenu = false
  @StateObject var game: GameContainer

  var body: some View {
    VStack {
      if let snapshot = game.gameState.gameSnapshot {
        VStack(spacing: 0) {
          VStack {
            if let player = snapshot.players.first { $0.position == .noord },
               !player.done {
                 PlayerView(
                   player: player,
                   orientation: .horizontal,
                   playerOnTurn: game.gameState.gameSnapshot?.playersOnTurn
                     .contains(player.id) ?? false
                 )
               }
            Spacer()
            HStack {
              if let player = snapshot.players.first { $0.position == .west },
                 !player.done {
                   PlayerView(
                     player: player,
                     orientation: .vertical,
                     playerOnTurn: game.gameState.gameSnapshot?.playersOnTurn
                       .contains(player.id) ?? false
                   )
                 }

              Spacer()

              if let player = snapshot.players.first { $0.position == .oost },
                 !player.done {
                   PlayerView(
                     player: player,
                     orientation: .vertical,
                     playerOnTurn: game.gameState.gameSnapshot?.playersOnTurn
                       .contains(player.id) ?? false
                   )
                 }
            }
            Spacer()

            if let player = snapshot.players.first { $0.position == .zuid },
               !player.done {
                 PlayerView(
                   player: player,
                   orientation: .horizontal,
                   playerOnTurn: game.gameState.gameSnapshot?.playersOnTurn
                     .contains(player.id) ?? false
                 )
               }
          }
          .padding()
          .background(Color.blue)
          .overlay(
            TableView(
              tableCards: snapshot.tableCards
            )
          )
          .overlay(
            CardStackView(cards: snapshot.deckCards, offset: 2).padding(),
            alignment: Alignment.topLeading
          )
          .overlay(
            CardStackView(cards: snapshot.burntCards, offset: 2)
              .padding(),
            alignment: Alignment.topTrailing
          )
          LocalPlayerView(
            closedCards: game.gameState.localClosedCards,
            phase: game.gameState.localPhase,
            error: game.gameState.error,
            cards: game.gameState.localCards,
            selectedCards: game.selectedCards,
            isOnTurn: game.gameState.isOnTurn,
            canPass: game.gameState.canPass,
            explain: game.gameState.explain,
            playClosedCard: { index in
              game.playClosedCard(index)
            }, select: {
              game.select(
                $0,
                selected: $1,
                deleteNotSameNumber: !game.gameState.isBeginMove
              )
            }, play: {
              game.play()
            }
          )
        }
        .transition(.move(edge: .top))
        .animation(.linear, value: snapshot)
      } else {
        Text("Loading...")
        ProgressView()
      }
    }
    .overlay(Button("Menu", action: {
      showMenu = true
    }).foregroundColor(Color.green).padding(), alignment: .topTrailing)
    .overlay(EndStateView(endState: game.gameState.endState, restart: {
      async {
      await game.restart()
      }
    }, quit: {
      self.state = nil
    }))
    .actionSheet(isPresented: $showMenu, content: {
      ActionSheet(title: Text("Weet je zeker dat je wilt stoppen?"), message: nil, buttons: [
        .destructive(Text("Stoppen"), action: {
          async {
            await game.stop()
            await MainActor.run {
              state = nil
            }
          }
        }),
        .cancel(),
      ])
    })
//    #if os(iOS)
//      .task {
//        switch gameType {
//        case .offline:
//          if case let .singlePlayer(contestants) = self.state {
//            await game.start(contestants: contestants)
//          }
//        case let .online(handler):
//          await game.startOnline(handler, restart: false)
//        }
//      }
//    #else
//      .onAppear {
//        async {
//          switch gameType {
//          case .offline:
//            if case let .singlePlayer(contestants) = self.state {
//              await game.start(contestants: contestants)
//            }
//          case let .online(handler):
//            await game.startOnline(handler, restart: false)
//          }
//        }
//      }
//    #endif
  }
}
