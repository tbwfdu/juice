//
//  Item.swift
//  Juice_iOS
//
//  Created by Pete Lindley on 8/2/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
