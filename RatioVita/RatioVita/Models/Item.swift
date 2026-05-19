//
//  Item.swift
//  RatioVita
//
//  Created by CFM Group International on 2025-09-02.
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
