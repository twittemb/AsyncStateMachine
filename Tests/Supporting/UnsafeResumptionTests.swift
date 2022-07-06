//
//  UnsafeResumptionTests.swift
//  
//
//  Created by Thibault WITTEMBERG on 10/07/2022.
//

@testable import AsyncStateMachine
import XCTest

final class UnsafeResumptionTests: XCTestCase {
  struct MockError: Error, Equatable {
    let value = Int.random(in: 0...100)
  }

  func test_resume_resumes_with_result_when_instantiated_with_success() async {
    let expectedInt = Int.random(in: 0...100)

    let receivedResult: Int = await withUnsafeContinuation { continuation in
      let sut = UnsafeResumption<Int, Never>(continuation: continuation, success: expectedInt)
      sut.resume()
    }

    XCTAssertEqual(receivedResult, expectedInt)
  }

  func test_resume_resumes_with_void_when_instantiated_without_result() async {
    let _: Void = await withUnsafeContinuation { continuation in
      let sut = UnsafeResumption<Void, Never>(continuation: continuation)
      sut.resume()
    }
  }

  func test_resume_throws_error_when_instantiated_with_failure() async {
    let expectedError = MockError()

    do {
      _ = try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Int, Error>) in
        let sut = UnsafeResumption<Int, Error>(continuation: continuation, failure: expectedError)
        sut.resume()
      }
      XCTFail("The continuation should fail")
    } catch let receivedError as MockError {
      XCTAssertEqual(receivedError, expectedError)
    } catch {
      XCTFail("The continuation should fail with a MockError")
    }
  }

  func test_resume_throws_error_when_instantiated_with_catching_body() async {
    let expectedError = MockError()

    do {
      _ = try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Int, Error>) in
        let sut = UnsafeResumption<Int, Error>(continuation: continuation, catching: { throw expectedError })
        sut.resume()
      }
      XCTFail("The continuation should fail")
    } catch let receivedError as MockError {
      XCTAssertEqual(receivedError, expectedError)
    } catch {
      XCTFail("The continuation should fail with a MockError")
    }
  }
}
