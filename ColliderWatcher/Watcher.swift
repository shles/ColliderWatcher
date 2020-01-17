//
//  Watcher.swift
//  ColliderWatcher
//
//  Created by Артeмий Шлесберг on 29/01/2019.
//  Copyright © 2019 Collider. All rights reserved.
//

import Foundation
import RealmSwift
import RxSwift
import CFNetwork
import SystemConfiguration.CaptiveNetwork

class Watcher {

    private var timer: Timer?
    private lazy var observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
    private var currentRecord: StatisticRecord?
    private var currentFrame: Timeframe?
    
    private var currentTime: Double = {
        return UserDefaults.standard.double(forKey: "time")
        }()
        {
        didSet {
            UserDefaults.standard.set(currentTime, forKey: "time")
        }
    }
    private var rate: Double
    private let realm  = try! Realm()
    
    var shouldWatch: Bool = true
    
    var timeAndAmount: Observable<(String, String)> {
        return timeSubject.asObservable()
    }
    private var timeSubject = PublishSubject<(String, String)>()
    //TODO: change from delegage to observables
    var isInCollider: Observable<Bool> {
        return isInColliderSubject.asObservable()
    }
    private var isInColliderSubject = PublishSubject<Bool>()
    
    init(ratePerHour: Double) {
        self.rate = ratePerHour / 60 / 60
        
        currentRecord =  realm.object(ofType: StatisticRecord.self, forPrimaryKey: StatisticRecord.getDateKey(date: Date()))
        if currentRecord == nil {
            currentRecord = StatisticRecord()
            try! realm.write {
                realm.add(currentRecord!)
            }
        }

        
        NotificationCenter.default.addObserver(self, selector: #selector(appWillTerminate), name: UIApplication.willTerminateNotification, object: nil)
    }
    
    @objc func appWillTerminate() {
        print("appWillTerminate")
        stop()
    }
    
    func start() {
        guard timer == nil else {
            return
        }
        if let frame = currentRecord?.frames.last, !frame.completed {
            currentFrame = frame
        } else {
            currentFrame = Timeframe()
            try! realm.write {
                currentRecord?.frames.append(currentFrame!)
            }
        }
        let interval = 0.01
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        var counter = 0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: { [weak self] (timer) in
            guard let strogSelf = self else { return }
            strogSelf.currentTime = strogSelf.currentRecord!.totalTime + strogSelf.currentFrame!.lastUpdate.timeIntervalSinceNow * -1
            let time = dateFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(strogSelf.currentTime)).addingTimeInterval(-3 * 60 * 60))
            let amount = "₽\(String(format: "%.1f",strogSelf.currentTime * strogSelf.rate))"
            strogSelf.timeSubject.onNext((time, amount))
            counter += 1
            if counter % 100 == 0, let frame = strogSelf.currentFrame {
                try! strogSelf.realm.write {
                    frame.amount = Date().timeIntervalSince(frame.start)
                }
            }
        })
        
    }
    
    func stop() {
        if let frame = currentRecord?.frames.last, !frame.completed {
            try! realm.write {
                frame.completed = true
            }
        }
        if let frame = currentFrame, let record = currentRecord {
            try! realm.write {
                frame.completed = true
                frame.amount = Date().timeIntervalSince(frame.start)
            }
            currentFrame = nil
            if  Calendar.current.component(.day, from: Date()) != Calendar.current.component(.day, from: record.date) {
                currentRecord = StatisticRecord()
            }
        }
        timer?.invalidate()
        timer = nil
    }
    
    func checkWifi() {
        networkChanged()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        observer,
                                        { (_, observer, name, _, _) -> Void in
                                            if let observer = observer, let name = name {
                                                // Extract pointer to `self` from void pointer:
                                                let mySelf = Unmanaged<Watcher>.fromOpaque(observer).takeUnretainedValue()
                                                // Call instance method:
                                                mySelf.networkChanged()
                                            }
        },
                                        "com.apple.system.config.network_change" as CFString,
                                        nil,
                                        CFNotificationSuspensionBehavior.deliverImmediately
        )
    }
    
    func networkChanged() {
        print("Recieved notification: n etwork changed")
        //TODO: достать последнюю запись, если она не закрыта. Если нетворка не будет то закрыть ее. Если нетворк есть то продолжить считать.
        if let interfaces = CNCopySupportedInterfaces() {
            for i in 0..<CFArrayGetCount(interfaces) {
                let interfaceName: UnsafeRawPointer = CFArrayGetValueAtIndex(interfaces, i)
                let rec = unsafeBitCast(interfaceName, to: AnyObject.self)
                let unsafeInterfaceData = CNCopyCurrentNetworkInfo("\(rec)" as CFString)
                if let interfaceData = unsafeInterfaceData as? [String: AnyObject] {
                    if interfaceData["BSSID"] as! String ==  "90:4c:81:1f:5e:f0" || interfaceData["SSID"] as! String == "Collider" {
                        
                        isInColliderSubject.onNext(true)
                        guard shouldWatch else {
                            return
                        }
                        self.start()
                        print("Still here")
                        return
                    }
                }
            }
        }
        isInColliderSubject.onNext(false)
        self.stop()
    }
}
