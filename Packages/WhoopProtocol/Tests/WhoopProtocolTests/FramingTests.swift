import XCTest

@testable import WhoopProtocol

final class Tests : XCTestCase{
    func test_zero() {
        let res = crc8([])
        XCTAssertEqual(crc8([]), 0, "expected 0, got \(res)")
    }

    func test_1(){
        let res = crc8(Array("1".utf8))
        XCTAssertEqual(res, 151, "expected 151, got \(res)")
    }

    func test_9(){
        let res = crc8(Array("123456789".utf8))
        XCTAssertEqual(res, 0xF4, "expected \(0xF4), got \(res)")
    }
}