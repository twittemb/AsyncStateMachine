//
//  DSLCompatibleTests.swift
//
//
//  Created by Thibault WITTEMBERG on 20/06/2022.
//

@testable import AsyncStateMachine
import XCTest

final class DSLCompatibleTests: XCTestCase {
  enum State: DSLCompatible {
    case s1
    case s2(value: String)
    case s3
    case s4(value: Int)
  }

  struct Value: DSLCompatible {}

  func test_label_returns_label_when_enum_without_associated_value() {
    let sut = State.s1
    XCTAssertEqual(sut.label, "s1")
  }

  func test_label_returns_label_when_enum_with_associated_value() {
    let sut = State.s2(value: "1")
    XCTAssertEqual(sut.label, "s2")
  }

  func test_label_returns_description_when_no_children() {
    let sut = Value()
    XCTAssertEqual(sut.label, String(describing: sut))
  }

  func test_decompose_return_path_when_no_associated_value() {
    // Given
    let sut = State.s1

    // When
    let expected = (path: ["s1"], associatedValue: ())
    let received = sut.decompose(expecting: Void.self)

    // Then
    XCTAssertEqual(received?.path, expected.path)
    XCTAssert(received?.associatedValue is Void)
  }

  func test_matches_returns_true_when_self_has_no_associated_value_and_other_is_same_case_without_associated_value() {
    let sut = State.s1
    XCTAssertTrue(sut.matches(State.s1))
  }

  func test_matches_returns_false_when_self_has_no_associated_value_and_other_is_another_case_without_associated_value() {
    let sut = State.s1
    XCTAssertFalse(sut.matches(State.s3))
  }

  func test_matches_returns_false_when_self_has_no_associate_value_and_other_is_another_case_with_associated_value() {
    let sut = State.s1
    XCTAssertFalse(sut.matches(State.s2(value:)))
  }

  func test_matches_returns_true_when_self_has_associated_value_and_other_is_same_case_with_associated_value() {
    let sut = State.s2(value: "1")
    XCTAssertTrue(sut.matches(State.s2(value:)))
  }

  func test_matches_returns_false_when_self_has_associated_value_and_other_is_another_case_with_associated_value() {
    let sut = State.s2(value: "1")
    XCTAssertFalse(sut.matches(State.s4(value:)))
  }

  func test_matches_returns_false_when_self_has_associated_value_and_other_is_another_case_without_associated_value() {
    let sut = State.s2(value: "1")
    XCTAssertFalse(sut.matches(State.s1))
  }

  func test_associatedValue_returns_value_when_expected_type() {
    let sut = State.s2(value: "value")
    XCTAssertEqual(sut.associatedValue(expecting: String.self), "value")
  }

  func test_associatedValue_returns_nil_when_unexpected_type() {
    let sut = State.s2(value: "value")
    XCTAssertNil(sut.associatedValue(expecting: Int.self))
  }

  func test_associatedValue_returns_value_when_other_matches() {
    let sut = State.s2(value: "value")
    XCTAssertEqual(sut.associatedValue(matching: State.s2(value:)), "value")
  }

  func test_associatedValue_returns_nil_when_other_does_not_matche() {
    let sut = State.s2(value: "value")
    XCTAssertNil(sut.associatedValue(matching: State.s4(value:)))
  }

  func test_decompose_return_path_and_value_when_associated_value() {
    // Given
    let sut = State.s2(value: "value")

    // When
    let expected = (path: ["s2", "(value: String)", "value", "String"], associatedValue: "value")
    let received = sut.decompose(expecting: String.self)

    // Then
    XCTAssertEqual(received?.path, expected.path)
    XCTAssertEqual(received?.associatedValue, expected.associatedValue)
  }

  func test_decompose_returns_nil_when_not_an_enum() {
    struct NotAnEnum: DSLCompatible {}

    // Given
    let sut = NotAnEnum()

    // When
    // Then
    XCTAssertNil(sut.decompose(expecting: String.self))
  }
}
