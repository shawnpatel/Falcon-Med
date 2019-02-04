//
//  FlightSummaryDetailsTableViewController.swift
//  Falcon Med
//
//  Created by Shawn Patel on 2/3/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import UIKit

class FlightSummaryDetectedPersonCell: UITableViewCell {
    @IBOutlet weak var person: UILabel!
    
    @IBOutlet weak var coordinates: UILabel!
    @IBOutlet weak var altitude: UILabel!
    
    @IBOutlet weak var leftEyeOpen: UILabel!
    @IBOutlet weak var rightEyeOpen: UILabel!
    
    @IBOutlet weak var gender: UILabel!
    @IBOutlet weak var age: UILabel!
    @IBOutlet weak var scene: UILabel!
    
    @IBOutlet weak var personImageView: UIImageView!
}

class FlightSummaryHistoricalDataCell: UITableViewCell {
    @IBOutlet weak var timestamp: UILabel!
    
    @IBOutlet weak var coordinates: UILabel!
    @IBOutlet weak var altitude: UILabel!
    @IBOutlet weak var heading: UILabel!
}

class FlightSummaryDetailsTableViewController: UITableViewController {
    
    // Global Variables
    var detectedPeople: [DetectedPerson]!
    var historicalData: [HistoricalData]!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if detectedPeople == nil {
            detectedPeople = []
        }
        
        if historicalData == nil {
            historicalData = []
        }
    }

    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 300
        } else if indexPath.section == 1 {
            return 65
        }
        
        return 0
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return detectedPeople.count
        } else if section == 1 {
            return historicalData.count
        }
        
        return 0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Detected People"
        } else if section == 1 {
            return "Historical Data"
        }
        
        return ""
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Section 1 - Detected People
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DetectedPersonCell", for: indexPath) as! FlightSummaryDetectedPersonCell
            
            let person = detectedPeople[indexPath.row]
            
            cell.person.text = "Person \(indexPath.row + 1)"
            
            cell.coordinates.text = "\(person.latitude), \(person.longitude)"
            cell.altitude.text = "\(person.altitude) FT"
            
            cell.leftEyeOpen.text = "\(person.leftEyeOpenProbability)%"
            cell.rightEyeOpen.text = "\(person.rightEyeOpenProbability)%"
            
            cell.gender.text = person.gender
            cell.age.text = person.age
            cell.scene.text = person.scene
            
            cell.personImageView.image = person.image
            
            return cell
        }
        
        // Section 2 - Historical Data
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoricalDataCell", for: indexPath) as! FlightSummaryHistoricalDataCell
        
        let data = historicalData[indexPath.row]
        
        cell.timestamp.text = data.timestamp.getTimeFromSecondsSince1970()
        
        cell.coordinates.text = "\(data.latitude), \(data.longitude)"
        cell.altitude.text = "\(data.altitude) FT"
        cell.heading.text = "\(data.heading)°"

        return cell
    }
}
