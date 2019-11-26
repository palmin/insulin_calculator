//
//  EstimateCaptureHistoryTableViewController.swift
//  insulin_calculator
//
//  Created by 李灿晨 on 10/23/19.
//  Copyright © 2019 李灿晨. All rights reserved.
//

import UIKit

class EstimateCaptureHistoryTableViewController: UITableViewController {
    
    var estimateCaptures: [EstimateCapture]? {
        didSet {
            guard estimateCaptures != nil else {return}
            if oldValue == nil || estimateCaptures!.count != oldValue!.count {
                tableView.reloadData()
            } else {
                let changedIndices = zip(estimateCaptures!, oldValue!).map{$0.0 != $0.1}.enumerated().filter{$1}.map{$0.0}
                guard changedIndices.count == 1 else {return}
                dataManager.updateEstimateCapture(capture: estimateCaptures![changedIndices.first!]) { error in
                    self.tableView.reloadRows(at: [self.editingIndexPath!], with: .automatic)
                }
            }
        }
    }
    
    private let dataManager: DataManager = DataManager.shared
    
    private var editingIndexPath: IndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        dataManager.getAllEstimateCaptures() { captures, error in
            self.estimateCaptures = captures
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        guard segue.identifier != nil else {return}
        switch segue.identifier! {
        case "showEstimateCaptureSubmissionViewController":
            let nc = segue.destination as! UINavigationController
            let destination = nc.topViewController as! EstimateCaptureSubmissionViewController
            destination.delegate = self
            destination.estimateCapture = estimateCaptures![editingIndexPath!.row]
        default:
            break
        }
    }
    
}


extension EstimateCaptureHistoryTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        guard estimateCaptures != nil else {return 0}
        return estimateCaptures!.count
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "estimateCaptureHistoryTableViewCell",
            for: indexPath
        )
        return cell
    }
    
    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        let cell = cell as! EstimateCaptureHistoryTableViewCell
        cell.estimateCapture = estimateCaptures?[indexPath.row]
    }
    
    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        editingIndexPath = indexPath
        tableView.deselectRow(at: indexPath, animated: true)
        if estimateCaptures![indexPath.row].isSubmitted! {return}
        performSegue(withIdentifier: "showEstimateCaptureSubmissionViewController", sender: nil)
    }
    
    override func tableView(
        _ tableView: UITableView,
        heightForRowAt indexPath: IndexPath
    ) -> CGFloat {
        return 100
    }
}


extension EstimateCaptureHistoryTableViewController: EstimateCaptureSubmissionDelegate {
    func submissionViewControllerClosed(submitted: Bool) {
        guard editingIndexPath != nil else {return}
        print(submitted)
        if submitted {
            estimateCaptures![editingIndexPath!.row].isSubmitted = true
        }
        self.editingIndexPath = nil
    }
}
