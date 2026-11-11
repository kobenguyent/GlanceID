import XCTest
import SwiftUI
@testable import GlanceID

final class ReticleBracketShapeTests: XCTestCase {
    func testShapeGeneratesPath() {
        let shape = ReticleBracketShape(cornerRadius: 16, bracketLength: 32)
        let rect = CGRect(x: 0, y: 0, width: 150, height: 150)
        let path = shape.path(in: rect)
        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(path.boundingRect.width, 150, accuracy: 2.0)
        XCTAssertEqual(path.boundingRect.height, 150, accuracy: 2.0)
    }
    
    func testShapeAnimatableData() {
        var shape = ReticleBracketShape(cornerRadius: 12, bracketLength: 24)
        XCTAssertEqual(shape.animatableData.first, 12)
        XCTAssertEqual(shape.animatableData.second, 24)
        
        shape.animatableData = AnimatablePair(20, 40)
        XCTAssertEqual(shape.cornerRadius, 20)
        XCTAssertEqual(shape.bracketLength, 40)
    }
    
    func testShapeZeroOrNegativeRect() {
        let shape = ReticleBracketShape(cornerRadius: 16, bracketLength: 32)
        let emptyRect = CGRect.zero
        let path = shape.path(in: emptyRect)
        XCTAssertTrue(path.isEmpty)
    }
}
