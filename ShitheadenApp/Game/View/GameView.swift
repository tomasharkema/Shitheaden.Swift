//
//  GameView.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 21/06/2021.
//

import ShitheadenRuntime
import SwiftUI

enum GameType {
  case offline
  case online(WebSocketHandler)
}

struct GameView: View {
  @Binding var state: AppState?
  let gameType: GameType
  @State var showMenu = false
  @StateObject var game = GameContainer()

  var body: some View {
    VStack {
      if let snapshot = game.gameSnapshot {
        VStack(spacing: 0) {
          VStack {
            if let player = snapshot.players.first { $0.position == .noord }, !player.done {
              PlayerView(
                player: player,
                orientation: .horizontal,
                playerOnTurn: player.id == game.gameSnapshot?.playerOnTurn
              )
            }
            Spacer()
            HStack {
              if let player = snapshot.players.first { $0.position == .west }, !player.done {
                PlayerView(
                  player: player,
                  orientation: .vertical,
                  playerOnTurn: player.id == game.gameSnapshot?.playerOnTurn
                )
              }

              Spacer()

              if let player = snapshot.players.first { $0.position == .oost }, !player.done {
                PlayerView(
                  player: player,
                  orientation: .vertical,
                  playerOnTurn: player.id == game.gameSnapshot?.playerOnTurn
                )
              }
            }
            Spacer()

            if let player = snapshot.players.first { $0.position == .zuid }, !player.done {
              PlayerView(
                player: player,
                orientation: .horizontal,
                playerOnTurn: player.id == game.gameSnapshot?.playerOnTurn
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
            closedCards: game.localClosedCards,
            phase: game.localPhase,
            error: game.error,
            cards: game.localCards,
            selectedCards: game.selectedCards,
            isOnSet: game.isOnSet, canPass: game.canPass,
            playClosedCard: { i in
              game.playClosedCard(i)
            }, select: {
              game.select($0, selected: $1, deleteNotSameNumber: game.moveHandler != nil)
            }, play: {
              game.play()
            }
          )
        }
        .transition(.move(edge: .top))
        .animation(.linear, value: snapshot)
      }
    }
    .navigationBarItems(trailing: Button("Menu", action: {
//        state = nil
      showMenu = true
    }))
    .actionSheet(isPresented: $showMenu, content: {
      ActionSheet(title: Text("Weet je zeker dat je wilt stoppen?"), message: nil, buttons: [
        .destructive(Text("Stoppen"), action: {
          withAnimation {
            game.stop()
            state = nil
          }
        }),
        .cancel(),
      ])
    })
    #if os(iOS)
      .task {
        switch gameType {
        case .offline:
          await game.start()
        case let .online(handler):
          await game.startOnline(handler)
        }
      }
    #else
      .onAppear {
        async {
          switch gameType {
          case .offline:
            await game.start()
          case let .online(handler, code):
            await game.startOnline(handler, code: code)
          }
        }
      }
    #endif
  }
}
