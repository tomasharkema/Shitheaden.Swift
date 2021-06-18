//
//  Either.swift
//
//
//  Created by Tomas Harkema on 15/06/2021.
//

import Foundation

public enum Either<Left, Right> {
  case left(Left), right(Right)
}
