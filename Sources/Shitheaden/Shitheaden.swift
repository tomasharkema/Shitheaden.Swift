//
//  Shitheaden.swift
//  EenEnDertigen
//
//  Created by Tomas Harkema on 18-07-15.
//  Copyright © 2015 Tomas Harkema. All rights reserved.
//

import Foundation

@main
enum Shitheaden {
//  static func main() async {
  static func main() async {
//    async {
    let args = CommandLine.arguments

    var tournament = false

    if args.count > 1 {
      let arg = args[1]

      if arg == "test-ai" {
        tournament = true
      }
    }

    if tournament {
      await Tournament(roundsPerGame: 10).playTournament()
    } else {
      let game = Game(shouldPrint: true)
      await game.startGame(restartClosure: {
        Position.input >>> "Type 'r' om het spel te herstarten..."
        let input = await Keyboard.getKeyboardInput()
        if input == "r" {
          fflush(__stdoutp)
          return true
        } else {
          return false
        }
      }, finishClosure: {
        Position.input >>> "Einde!"
        let input = await Keyboard.getKeyboardInput()
        if input == "r" {
          fflush(__stdoutp)
          return true
        } else {
          return false
        }
      })
//    }
    }
  }
}
