//
//  Item.swift
//  SymptomNerd
//
//  Created by Dave Lummy on 1/31/26.
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
