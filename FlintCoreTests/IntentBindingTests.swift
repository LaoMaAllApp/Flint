//
//  IntentBindingTests.swift
//  FlintCore
//
//  Created by Marc Palmer on 05/01/2019.
//  Copyright © 2019 Montana Floss Co. Ltd. All rights reserved.
//

import XCTest
@testable import FlintCore

class IntentBindingTests: XCTestCase {

    override func setUp() {
        Flint.resetForTesting()
        Flint.register(group: DummyFeatures.self)
    }

    override func tearDown() {
    }

    func testIntentIsMappedToAction() {
        let mapping: IntentMapping? = IntentMappings.shared.mapping(for: DummyIntent.self)
        XCTAssertNotNil(mapping, "Expected to have a mapping for the intent")
        XCTAssert(mapping?.intentType == DummyIntent.self, "Incorrect mapping")
    }
    
    func testPerformIntent() {
    }
}
