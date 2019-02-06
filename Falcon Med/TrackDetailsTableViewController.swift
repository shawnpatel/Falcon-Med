//
//  TrackDetailsTableViewController.swift
//  Falcon Med
//
//  Created by Shawn Patel on 2/6/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import UIKit

class TrackDetectedPersonCell: UITableViewCell {
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

class TrackDetailsTableViewController: UITableViewController {
    
    // Global Variables
    var detectedPeople: [DetectedPerson]!

    override func viewDidLoad() {
        super.viewDidLoad()

        if detectedPeople == nil {
            detectedPeople = []
        }
    }

    // MARK: - Table view data source
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 300
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return detectedPeople.count
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Detected People"
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! TrackDetectedPersonCell
        
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
}
