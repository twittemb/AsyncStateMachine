//
//  AsyncThrowingSequence.swift
//  
//
//  Created by Thibault WITTEMBERG on 09/07/2022.
//

struct MockError: Error {}

struct AsyncThrowingSequence<Element>: AsyncSequence {
  typealias Element = Element
  typealias AsyncIterator = Iterator

  func makeAsyncIterator() -> AsyncIterator {
    Iterator()
  }

  struct Iterator: AsyncIteratorProtocol {
    func next() async throws -> Element? {
      throw MockError()
    }
  }
}
