//
//  StaticActionBinding+iOS+Extensions.swift
//  FlintCore-iOS
//
//  Created by Marc Palmer on 25/06/2018.
//  Copyright © 2018 Montana Floss Co. Ltd. All rights reserved.
//

import Foundation

// Workaround for inability to compile against just iOS 12+, using the new "Network" framework as an indicator
#if canImport(Network) && os(iOS)
extension StaticActionBinding {

    /// Call to invoke the system "Add Voice Shortcut" view controller for the given input to the conditionally-available
    /// action represented by this action request. The action must support creating an `INIntent` for a custom intent extension
    /// to be invoked, or creating an `NSUserActivity` using Flint's Activities conventions.
    ///
    /// This will create a shortcut that invokes the `INIntent` returned by the `Action`'s `intent(for:)` function.
    /// If that function returns nil (or is not defined by your `Action`), it will attempt to create an `NSUserActivity`
    /// for the `Action` and instead use that. If the `Action` does not support `Activities`, this will fail.
    ///
    /// - param input: The input to pass to the action when it is later invoked from the Siri Shortcut by the user.
    /// - param presenter: The `UIViewController` to use to present the view controller
    @available(iOS 12, *)
    public func addVoiceShortcut(for input: ActionType.InputType, presenter: UIViewController) {
        VoiceShortcuts.addVoiceShortcut(action: ActionType.self, feature: FeatureType.self, for: input, presenter: presenter)
    }
}

extension StaticActionBinding where ActionType: IntentAction {
    @available(iOS 12, *)
    public func perform(intent: ActionType.IntentType, presenter: ActionType.PresenterType) -> MappedActionResult {
//        guard let request = SiriFeature.handleIntent.request() else {
//            return .featureDisabled
//        }

        /// !!! TODO: We probably need a Result<T> here as nil could be valid
        guard let inputFromIntent = ActionType.input(for: intent) else {
            flintUsageError("Failed to create input from intent \(intent)")
        }

//        let intentWrapper = FlintIntentWrapper(intent: intent)
        
        var syncOutcome: ActionPerformOutcome?
        let completion = Action.Completion(queue: nil) { (outcome, wasAsync) in
            FlintInternal.logger?.debug("Intent perform outcome: \(outcome) wasAsync: \(wasAsync)");
            syncOutcome = outcome
        }

        let status: Action.Completion.Status = perform(input: inputFromIntent, presenter: presenter, userInitiated: true, source: .intent, completion: completion)

        if status.isCompletingAsync {
            return .completingAsync
        }
        
        guard let outcome = syncOutcome else {
            flintBug("We should have a sync outcome by now");
        }
        
        let result: MappedActionResult
        
        switch outcome {
            case .success,
                 .successWithFeatureTermination:
                result = .success
            case .failure(let error),
                 .failureWithFeatureTermination(let error):
                switch error {
                    case DispatchIntentAction.IntentActionError.noMappingFound:
                        result = .noMappingFound
                    default:
                        result = .failure(error: error)
                }
        }
        
        return result
    }

    /// Donate an intent-based shortcut that will invoke this `Action` to Siri for the given input.
    @available(iOS 12, *)
    public func donateToSiri(for input: ActionType.InputType) {
        guard let intent = action.intent(for: input) else {
            flintUsageError("Cannot donate intent to Siri, action type \(action) did not return an intent for input: \(input).")
        }
        if let request = IntentShortcutDonationFeature.donateShortcut.request() {
            let intentWrapper = FlintIntentWrapper(intent: intent)
            request.perform(input: intentWrapper)
        }
    }
}
#endif
