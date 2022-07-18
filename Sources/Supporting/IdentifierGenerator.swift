//
//  IdentifierGenerator.swift
//  
//
//  Created by Thibault WITTEMBERG on 19/07/2022.
//

final class IdentifierGenerator: Sendable {
  let state = ManagedCriticalState<Int>(0)

  func generate() -> Int {
    self.state.withCriticalRegion { current in
      current += 1
      return current
    }
  }
}
