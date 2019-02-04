//
//  HistoryTableViewController.swift
//  Falcon Med
//
//  Created by Shawn Patel on 2/3/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import UIKit

import Firebase

class HistoryTableViewCell: UITableViewCell {
    @IBOutlet weak var date: UILabel!
}

class HistoryTableViewController: UITableViewController {
    
    // Firebase
    var databaseRef: DatabaseReference!
    var uid: String!
    
    // Global Variables
    var takeoffTimes: [Int]!
    
    var detectedPeople: [[DetectedPerson]]!
    var historicalData: [[HistoricalData]]!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        takeoffTimes = []
        
        detectedPeople = []
        historicalData = []
        
        downloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        databaseRef = Database.database().reference()
        uid = Auth.auth().currentUser?.uid
    }
    
    func downloadData() {
        databaseRef.child("flights").child(uid).child("historical").observeSingleEvent(of: .value, with: { (snapshot) in
            let value = snapshot.value as? NSDictionary
            
            for takeoffTime in (value?.allKeys as! [String]) {
                self.takeoffTimes.append(Int(takeoffTime)!)
            }
            
            self.takeoffTimes.sort()
            self.takeoffTimes.reverse()
            
            self.tableView.reloadData()
        }) { (error) in
            print(error.localizedDescription)
        }
    }

    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if takeoffTimes != nil {
            return takeoffTimes.count
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! HistoryTableViewCell
        
        cell.date.text = takeoffTimes[indexPath.row].getDateFromSecondsSince1970()
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.performSegue(withIdentifier: "historyToFlightMap", sender: indexPath.row)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "historyToFlightMap" {
            if let destination = segue.destination as? FlightMapViewController {
                destination.detectedPeople = detectedPeople[sender as! Int]
                destination.historicalData = historicalData[sender as! Int]
            }
        }
    }
}
