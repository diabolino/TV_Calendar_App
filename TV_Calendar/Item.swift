//
//  Item.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 26/11/2025.
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
