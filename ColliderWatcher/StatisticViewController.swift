//
//  StatisticViewController.swift
//  ColliderWatcher
//
//  Created by Артeмий Шлесберг on 29/01/2019.
//  Copyright © 2019 Collider. All rights reserved.
//

import Foundation
import UIKit
import RxRealmDataSources
import RxDataSources
import RxSwift
import RxCocoa
import RealmSwift

class  StatisticViewController: UIViewController, UITableViewDelegate {
    
    private let disposeBag = DisposeBag()
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
    
        let dataSource = RxTableViewSectionedReloadDataSource<SectionModel<String, StatisticRecord>>(
            configureCell: { (ds, tv, ip, record) -> UITableViewCell in
                let cell = tv.dequeueReusableCell(withIdentifier: "statistic", for: ip) as! StatisticCell
                cell.dateLabel.text = dateFormatter.string(from: record.date)
                let time = timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(record.totalTime)).addingTimeInterval(-3 * 60 * 60))
                let amount = "₽\(String(format: "%.2f", record.totalPrice(ratePerHour: 3180.0)))"
                cell.timeLabel.text = time
                cell.moneyLabel.text = amount
                return cell
            },
            titleForHeaderInSection: { dataSource, sectionIndex in
                return dataSource[sectionIndex].model
        })
        
        let realm = try! Realm()

        let allRecords = realm.objects(StatisticRecord.self).sorted(byKeyPath: "date", ascending: false)
        
        struct Month: Hashable {
            var month: Int
            var year: Int
            
            var hashValue: Int {
                return year * 12 + month
            }
        }
        var months: Set<Month> = [] //moth, year
        
        allRecords.forEach {
            let components = Calendar.current.dateComponents([.month, .year], from: $0.date)
            months.insert(Month(month: components.month!, year: components.year!))
        }
        
        let sections = months.map { month -> SectionModel<String, StatisticRecord> in
            let monthRecords = allRecords.filter { record in
                let components = Calendar.current.dateComponents([.month, .year], from: record.date)
                return components.year == month.year && components.month == month.month
            }
            let total = monthRecords.reduce(0.0, { $0 + $1.totalPrice(ratePerHour: 3180.0) })
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM"
            return SectionModel<String, StatisticRecord>(
                model: "\(dateFormatter.string(from: monthRecords.first!.date)) Total: \(String(format: "%.2f", total))₽",
                items: Array(monthRecords)
            )
        }
        
        Observable.just(sections)
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
        
        tableView.rx
            .setDelegate(self)
            .disposed(by: disposeBag)
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 56
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        view.backgroundColor = #colorLiteral(red: 0.1083059683, green: 0.02741651237, blue: 0.01229097042, alpha: 1)
        view.tintColor = #colorLiteral(red: 0.1083059683, green: 0.02741651237, blue: 0.01229097042, alpha: 1)
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = #colorLiteral(red: 0.9086583257, green: 0.2709504366, blue: 0.08477353305, alpha: 1)
        header.textLabel?.font = UIFont.systemFont(ofSize: 32, weight: .bold)
    }
}

class StatisticCell: UITableViewCell {
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var moneyLabel: UILabel!
    
}
