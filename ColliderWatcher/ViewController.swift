//
//  ViewController.swift
//  ColliderWatcher
//
//  Created by Артeмий Шлесберг on 25/01/2019.
//  Copyright © 2019 Collider. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController  {

    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var drinkSwitch: UISwitch!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var activeView: UIView!
    @IBOutlet weak var drinkView: UIStackView!
    @IBOutlet weak var counterBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet weak var statisticTriggerLabel: UILabel!
    @IBOutlet weak var statisticStick: UIView!
    @IBOutlet weak var swipeView: UIView!
    
    private let sgr = UISwipeGestureRecognizer(target: nil, action: nil)
    private let tgr = UITapGestureRecognizer(target: nil, action: nil)
    private var disposeBag = DisposeBag()
    
    var isDrink: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "isDrink")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "isDrink")
        }
    }
    
    lazy var watcher = Watcher(ratePerHour: 3180)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sgr.direction = .up
        sgr.numberOfTouchesRequired = 1
        swipeView.addGestureRecognizer(sgr)
        tgr.numberOfTapsRequired = 1
        tgr.numberOfTouchesRequired = 1
        swipeView.addGestureRecognizer(tgr)
        drinkSwitch.rx.controlEvent(UIControlEvents.valueChanged)
        .map { [unowned self] in
            return self.drinkSwitch.isOn
        }
        .startWith(isDrink)
        .do(onNext: { [unowned self] in
            self.drinkSwitch.thumbTintColor = $0 ? UIColor(red: 25.0/255.0, green: 8.0/255.0, blue: 4.0/255.0, alpha: 1) : UIColor(red: 214.0/255.0, green: 82.0/255.0, blue: 44.0/255.0, alpha: 1)
        })
        .subscribe(onNext: { [unowned self] isDrink in
            self.activeView.isHidden = isDrink
            self.drinkView.isHidden = !isDrink
            self.watcher.shouldWatch = !isDrink
            if isDrink {
                self.watcher.stop()
            } else {
                self.watcher.networkChanged()
            }
            self.isDrink = isDrink
        }).disposed(by: disposeBag)
        drinkSwitch.isOn = isDrink
        
        self.counterBottomConstraint.constant = -(self.counterBottomConstraint.secondItem as! UIView).frame.height
        self.view.layoutIfNeeded()
        
        watcher.isInCollider.subscribe(onNext: { [unowned self] inCollider in
            
            self.counterBottomConstraint.constant = inCollider ? -20 : -(self.counterBottomConstraint.secondItem as! UIView).frame.height
           
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 0.9, initialSpringVelocity: 1.0, options: .curveEaseInOut, animations: {
                self.view.layoutIfNeeded()
            }) { _ in
                self.statisticStick.backgroundColor = inCollider ? #colorLiteral(red: 0.9086583257, green: 0.2709504366, blue: 0.08477353305, alpha: 1) : #colorLiteral(red: 0.1083059683, green: 0.02741651237, blue: 0.01229097042, alpha: 1)
                self.statisticTriggerLabel.textColor = inCollider ? #colorLiteral(red: 0.9086583257, green: 0.2709504366, blue: 0.08477353305, alpha: 1) : #colorLiteral(red: 0.1083059683, green: 0.02741651237, blue: 0.01229097042, alpha: 1)
            }
        }).disposed(by: disposeBag)
        
        watcher.timeAndAmount.subscribe(onNext: { [unowned self] in
            self.timeLabel.text = $0
            self.priceLabel.text = $1
        }).disposed(by: disposeBag)
        
        Observable.merge([
            sgr.rx.event.map { _ in ()},
            tgr.rx.event.map { _ in ()}
            ])
        .subscribe(onNext: { [unowned self] _ in
            //needs to record last changes
            //posibly sholud be refactored to realtime changes
            self.watcher.stop()
            self.watcher.start()
            self.performSegue(withIdentifier: "statistic", sender: nil)
        }).disposed(by: disposeBag)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d"
        dateLabel.text = dateFormatter.string(from: Date())
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        watcher.checkWifi()
    }
}




