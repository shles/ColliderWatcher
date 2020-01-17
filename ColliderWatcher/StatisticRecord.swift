//
//  StatisticRecord.swift
//  ColliderWatcher
//
//  Created by Артeмий Шлесберг on 28/01/2019.
//  Copyright © 2019 Collider. All rights reserved.
//

import Foundation
import RealmSwift
import Realm

class StatisticRecord: Object {
    @objc dynamic var date: Date = Date()
    
    var frames: List<Timeframe> = List<Timeframe>()
    
    var totalTime: Double  {
        return frames.reduce(0, { $0 + $1.amount})
    }
    func totalPrice(ratePerHour: Double) -> Double {
        return totalTime / 3600 * ratePerHour
    }
    @objc dynamic var interval: String = getDateKey(date: Date())
    
    override static func primaryKey() -> String? {
        return "interval"
    }
    
    static func getDateKey(date: Date) -> String {
        return Calendar.current.dateComponents([.day, .month, .year], from: date).description
    }
}

class Timeframe: Object {
    @objc dynamic var start: Date = Date()
    @objc dynamic var amount: Double = 0
    @objc dynamic var completed: Bool = false
    var lastUpdate: Date {
        return start.addingTimeInterval(amount)
    }
}
