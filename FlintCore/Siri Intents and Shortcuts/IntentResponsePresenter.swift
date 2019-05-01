//
//  IntentResultPresenter.swift
//  FlintCore-iOS
//
//  Created by Marc Palmer on 10/01/2019.
//  Copyright © 2019 Montana Floss Co. Ltd. All rights reserved.
//

import Foundation

/// The default presenter type for Intent Actions, which provides a single function
/// that will pass the INIntentResponse to the Intent Handler's completion function.
///
/// - note: This will assert that the respone is the expected type. We use generics here to get close to
/// true type safety, but because of the nature of the code generated by Xcode, we cannot have a truly statically
/// typed presenter — so we check the type of the response at the point of submitting.
public class IntentResponsePresenter<ResponseType> where ResponseType: FlintIntentResponse {
    let completion: (ResponseType) -> Void
    
    public init(completion: @escaping (ResponseType) -> Void) {
        self.completion = completion
    }
    
    /// Call to pass the response to Siri
    public func showResponse(_ response: FlintIntentResponse) {
        guard let safeResponse = response as? ResponseType else {
            fatalError("Wrong response type, expected \(ResponseType.self) but got \(type(of: response))")
        }
        completion(safeResponse)
    }
}


