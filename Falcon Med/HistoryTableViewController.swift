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
    
    var activityIndicator: UIActivityIndicatorView!
    
    // Firebase
    var databaseRef: DatabaseReference!
    var storage: Storage!
    var uid: String!
    
    // Global Variables
    var takeoffTimes: [Int]!
    var databaseData: [NSDictionary]!
    
    var detectedPeople: [DetectedPerson]!
    var historicalData: [HistoricalData]!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
        activityIndicator.backgroundColor = UIColor.lightGray
        activityIndicator.layer.cornerRadius = 5
        activityIndicator.center = view.convert(view.center, from: view.superview)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        tableView.isUserInteractionEnabled = false
        view.addSubview(activityIndicator)
        
        takeoffTimes = []
        databaseData = []
        
        detectedPeople = []
        historicalData = []
        
        downloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        databaseRef = Database.database().reference()
        storage = Storage.storage()
        uid = Auth.auth().currentUser?.uid
    }
    
    func downloadData() {
        databaseRef.child("flights").child(uid).child("historical").observeSingleEvent(of: .value, with: { (snapshot) in
            let databaseData = snapshot.value as? NSDictionary
            
            for takeoffTime in (databaseData?.allKeys as! [String]) {
                self.takeoffTimes.append(Int(takeoffTime)!)
            }
            
            self.takeoffTimes.sort()
            self.takeoffTimes.reverse()
            
            for takeoffTime in self.takeoffTimes {
                self.databaseData.append(databaseData![String(takeoffTime)] as! NSDictionary)
            }
            
            self.tableView.reloadData()
            
            self.activityIndicator.stopAnimating()
            self.tableView.isUserInteractionEnabled = true
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
        parseData(index: sender as! Int)
        
        if segue.identifier == "historyToFlightMap" {
            if let destination = segue.destination as? FlightMapViewController {
                destination.detectedPeople = detectedPeople
                destination.historicalData = historicalData
            }
        }
    }
    
    func parseData(index: Int) {
        let flightData = databaseData[index]
        for flight in flightData {
            let timestamp = flight.key as? String
            if timestamp != "faces" {
                let data = flight.value as! NSDictionary
                    
                let latitude = data.value(forKey: "latitude") as! Double
                let longitude = data.value(forKey: "longitude") as! Double
                let altitude = data.value(forKey: "altitude") as! Double
                let heading = data.value(forKey: "heading") as! Double
                    
                let historicalData = HistoricalData(Int(timestamp!)!, latitude, longitude, altitude, heading)
                self.historicalData.append(historicalData)
            }
        }
        
        let faces = flightData["faces"] as? NSDictionary
        if faces != nil {
            for case let face as NSDictionary in (faces?.allValues)! {
                let latitude = face.value(forKey: "latitude") as! Double
                let longitude = face.value(forKey: "longitude") as! Double
                let altitude = face.value(forKey: "altitude") as! Double
                
                let leftEyeOpenProbability = face.value(forKey: "leftEyeOpenProbability") as! Int
                let rightEyeOpenProbability = face.value(forKey: "rightEyeOpenProbability") as! Int
                
                let gender = face.value(forKey: "gender") as! String
                let age = face.value(forKey: "age") as! String
                let scene = face.value(forKey: "scene") as! String
                
                let imageURL = face.value(forKey: "image") as! String
                
                let detectedPerson = DetectedPerson(latitude, longitude, altitude, leftEyeOpenProbability, rightEyeOpenProbability, gender, age, scene)
                detectedPeople.append(detectedPerson)
                
                downloadImage(url: imageURL, index: detectedPeople.count - 1)
            }
        }
    }
    
    func downloadImage(url: String, index: Int) {
        let httpsRef = storage.reference(forURL: url)
        
        httpsRef.getData(maxSize: Int64.max) { data, error in
            if let error = error {
                print(error)
            } else {
                let image = UIImage(data: data!)
                
                self.detectedPeople[index].image = image!
            }
        }
    }
}
