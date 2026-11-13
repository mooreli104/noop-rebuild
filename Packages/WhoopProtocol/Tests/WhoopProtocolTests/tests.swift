import XCTest

@testable import WhoopProtocol

final class Tests : XCTestCase -> String{
    func testDummy() {
        XCTAssertEqual(main(), "hello world!", "function result different from expected")
    }
}