import XCTest
@testable import GifKeyboard

final class AppIconOptionTests: XCTestCase {

    func test_allCasesHaveNonEmptyNames() {
        for option in AppIconOption.allCases {
            XCTAssertFalse(option.rawValue.isEmpty, "\(option) has empty rawValue")
            XCTAssertFalse(option.displayName.isEmpty, "\(option) has empty displayName")
        }
    }

    func test_defaultHasNilAlternateIconName() {
        XCTAssertNil(AppIconOption.default.alternateIconName)
    }

    func test_nonDefaultCasesHaveNonNilAlternateIconName() {
        let alternates = AppIconOption.allCases.filter { $0 != .default }
        XCTAssertFalse(alternates.isEmpty)
        for option in alternates {
            XCTAssertNotNil(option.alternateIconName, "\(option) should have an alternateIconName")
            XCTAssertEqual(option.alternateIconName, option.rawValue)
        }
    }

    func test_fourOptionsExist() {
        XCTAssertEqual(AppIconOption.allCases.count, 4)
    }
}
