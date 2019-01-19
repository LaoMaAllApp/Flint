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
        Flint.quickSetup(DummyFeatures.self)
    }

    override func tearDown() {
    }

    @available(iOS 12, *)
    func testPerformIntent() {
        let intent = DummyIntent()
        let presenter = IntentResponsePresenter(completion: { (DummyIntentResponse) in
            
        })
        let result = DummyFeature.intentAction.perform(intent: intent, presenter: presenter)
        XCTAssert(result == .success)
    }
}
