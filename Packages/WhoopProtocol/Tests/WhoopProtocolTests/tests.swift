import XCTest

@testable import WhoopProtocol

final class Tests:XCTestCase{
    func test_main() {
        XCTAssertEqual(main(), "hello world!")
    }
    
}