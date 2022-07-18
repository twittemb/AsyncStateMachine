//
//  Consumer.swift
//  
//
//  Created by Thibault WITTEMBERG on 19/07/2022.
//

struct Consumer<Element>: Hashable, Sendable
where Element: Sendable {
  let identifier: Int
  let continuation: UnsafeContinuation<Element?, Never>?
  let cancelled: Bool

  init(
    identifier: Int,
    continuation: UnsafeContinuation<Element?, Never>?,
    cancelled: Bool = false
  ) {
    self.identifier = identifier
    self.continuation = continuation
    self.cancelled = cancelled
  }

  static func placeHolder(identifier: Int) -> Consumer {
    Consumer(
      identifier: identifier,
      continuation: nil,
      cancelled: false
    )
  }

  static func cancelled(identifier: Int) -> Consumer {
    Consumer(
      identifier: identifier,
      continuation: nil,
      cancelled: true
    )
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(self.identifier)
  }

  static func == (_ lhs: Consumer, _ rhs: Consumer) -> Bool {
    return lhs.identifier == rhs.identifier
  }
}
