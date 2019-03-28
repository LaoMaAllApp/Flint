//
//  SubscriptionProduct.swift
//  FlintCore
//
//  Created by Marc Palmer on 16/03/2019.
//  Copyright © 2019 Montana Floss Co. Ltd. All rights reserved.
//

import Foundation

/// A base product type for products that represent any kind of subscription
open class SubscriptionProduct: NoQuantityProduct {
    public override init(name: String, description: String? = nil, productID: String) {
        super.init(name: name, description: description, productID: productID)
    }
}
