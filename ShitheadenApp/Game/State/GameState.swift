//
//  GameState.swift
//  ShitheadenApp
//
//  Created by Tomas Harkema on 24/06/2021.
//

import CustomAlgo
import Foundation
import ShitheadenRuntime
import ShitheadenShared
import SwiftUI

struct GameState: Equatable {
  var gameSnapshot: GameSnapshot?
  var error: String?
  var localCards = [RenderCard]()
  var localPhase: Phase?
  var localClosedCards = [RenderCard]()
  var isOnTurn = false

  var canPass = false
  var endState: EndPlace?
  var explain: String?
  var isBeginMove = false
}
