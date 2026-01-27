//
//  Item.swift
//  SceneLing
//
//  Created by 知遇 on 2026/1/28.
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
