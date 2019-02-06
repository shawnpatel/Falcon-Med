//
//  TrackViewController.swift
//  Falcon Med
//
//  Created by Shawn Patel on 2/3/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import UIKit
import MapKit

import Firebase
import LMGaugeView

class TrackViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak var coordinates: UILabel!
    
    @IBOutlet weak var altitude: UILabel!
    @IBOutlet weak var heading: UILabel!
    
    @IBOutlet weak var speedGauge: LMGaugeView!
    
    @IBOutlet weak var accelX: UILabel!
    @IBOutlet weak var accelY: UILabel!
    @IBOutlet weak var accelZ: UILabel!
    
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var liveView: UIImageView!
    
    var activityIndicator: UIActivityIndicatorView!
    
    // Firebase
    var databaseRef: DatabaseReference!
    var storage: Storage!
    var uid: String!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
        activityIndicator.backgroundColor = UIColor.lightGray
        activityIndicator.layer.cornerRadius = 5
        activityIndicator.center = view.convert(view.center, from: view.superview)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)
        
        checkIfDroneIsLive()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup Map Properties
        map.delegate = self
        map.mapType = .hybrid
        map.showsUserLocation = true
        map.setUserTrackingMode(.follow, animated: true)
        
        // Setup Speed Gauge Properties
        speedGauge.minValue = 0
        speedGauge.maxValue = 10
        speedGauge.valueFont = UIFont.systemFont(ofSize: 48, weight: .semibold)
        speedGauge.unitOfMeasurementFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        
        // Instantiate Firebase Constants
        databaseRef = Database.database().reference()
        storage = Storage.storage()
        uid = Auth.auth().currentUser?.uid
    }
    
    func checkIfDroneIsLive() {
        databaseRef.child("flights").child(uid).child("live").observeSingleEvent(of: .value, with: { (snapshot) in
            self.activityIndicator.stopAnimating()
            if let databaseData = snapshot.value as? NSDictionary {
                // Live
                
                let latitude = databaseData["latitude"] as? Double
                let longitude = databaseData["longitude"] as? Double
                
                let altitude = databaseData["altitude"] as? Double
                let heading = databaseData["heading"] as? Int
                
                let speed = databaseData["speed"] as? Double
                
                let accelX = databaseData["accelX"] as? Double
                let accelY = databaseData["accelY"] as? Double
                let accelZ = databaseData["accelZ"] as? Double
                
                self.coordinates.text = "\(latitude!), \(longitude!)"
                
                self.altitude.text = "\(altitude!) FT"
                self.heading.text = "\(heading!)°"
                
                self.speedGauge.value = CGFloat(speed!)
                
                self.accelX.text = "\(accelX!) Gs"
                self.accelY.text = "\(accelY!) Gs"
                self.accelZ.text = "\(accelZ!) Gs"
                
                // Add Drone's Location to Map
                let annotation = MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(latitude!), longitude: CLLocationDegrees(longitude!))
                annotation.title = "Drone"
                self.map.addAnnotation(annotation)
                
                self.refreshData()
            } else {
                // Not Live
                
                let alertController = UIAlertController(title: "Not Live", message: "Your drone is currently not in flight.", preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        }) { (error) in
            print(error.localizedDescription)
        }
    }
    
    func refreshData() {
        databaseRef.child("flights").child(uid).child("live").observe(.childChanged, with: { (snapshot) -> Void in
            let key = snapshot.key
            let value = snapshot.value
            
            switch key {
                case "latitude":
                    var index = self.coordinates.text?.firstIndex(of: ",")
                    index = self.coordinates.text?.index(index!, offsetBy: 2)
                    let longitude = String((self.coordinates.text?.suffix(from: index!))!)
                
                    self.coordinates.text = "\(value as! Double), \(longitude)"
                
                    // Update Drone's Location on Map
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(value as! Double), longitude: CLLocationDegrees(Double(longitude)!))
                    annotation.title = "Drone"
                    self.map.removeAnnotations(self.map.annotations)
                    self.map.addAnnotation(annotation)
                case "longitude":
                    let index = self.coordinates.text?.firstIndex(of: ",")
                    let latitude = String((self.coordinates.text?.prefix(upTo: index!))!)
                
                    self.coordinates.text = "\(latitude), \(value as! Double)"
                    
                    // Update Drone's Location on Map
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(Double(latitude)!), longitude: CLLocationDegrees(value as! Double))
                    annotation.title = "Drone"
                    self.map.removeAnnotations(self.map.annotations)
                    self.map.addAnnotation(annotation)
                case "altitude":
                    self.altitude.text = "\(value as! Double) FT"
                case "heading":
                    self.heading.text = "\(value as! Int)°"
                case "speed":
                    self.speedGauge.value = CGFloat(value as! Double)
                case "accelX":
                    self.accelX.text = "\(value as! Double) Gs"
                case "accelY":
                    self.accelY.text = "\(value as! Double) Gs"
                case "accelZ":
                    self.accelZ.text = "\(value as! Double) Gs"
                case "image":
                    self.downloadImage(url: value as! String)
                default:
                    break
            }
        }) { (error) in
            print(error.localizedDescription)
        }
    }
    
    func downloadImage(url: String) {
        let httpsRef = storage.reference(forURL: url)
        
        httpsRef.getData(maxSize: Int64.max) { data, error in
            if let error = error {
                print(error)
            } else {
                let image = UIImage(data: data!)
                
                self.liveView.image = image
            }
        }
    }
    
    @IBAction func refresh(_ sender: UIBarButtonItem) {
        activityIndicator.startAnimating()
        checkIfDroneIsLive()
    }
}
