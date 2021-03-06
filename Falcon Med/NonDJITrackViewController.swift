//
//  TrackViewController.swift
//  Falcon Med
//
//  Created by Shawn Patel on 2/3/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import UIKit
import AVFoundation
import MapKit

import Firebase
import LMGaugeView

class NonDJITrackViewController: UIViewController, MKMapViewDelegate {

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
    var uid: String!
    
    // Global Variables
    var takeoffTime: Int!
    
    var detectedPeople: [DetectedPerson]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        detectedPeople = []
        
        // Create Activity Indicator
        activityIndicator = UIActivityIndicatorView(style: .whiteLarge)
        activityIndicator.backgroundColor = UIColor.lightGray
        activityIndicator.layer.cornerRadius = 0
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
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
        uid = Auth.auth().currentUser?.uid
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Center Activity Indicator
        activityIndicator.center = view.convert(view.center, from: view.superview)
    }
    
    func checkIfDroneIsLive() {
        NetworkCalls.downloadLiveData() { response in
            self.activityIndicator.stopAnimating()
            
            switch response {
            case .success(let liveData):
                // Live
                
                self.takeoffTime = liveData.takeoffTime
                
                self.coordinates.text = "\(liveData.latitude), \(liveData.longitude)"
                
                self.altitude.text = "\(liveData.altitude) FT"
                self.heading.text = "\(liveData.heading)°"
                
                self.speedGauge.value = CGFloat(liveData.speed)
                
                self.accelX.text = "\(liveData.accelX) Gs"
                self.accelY.text = "\(liveData.accelY) Gs"
                self.accelZ.text = "\(liveData.accelZ) Gs"
                
                // Add Drone's Location to Map
                let annotation = MKPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(liveData.latitude), longitude: CLLocationDegrees(liveData.longitude))
                annotation.title = "Drone"
                self.map.addAnnotation(annotation)
                
                self.refreshLiveData()
                self.refreshPersonDetection()
                
            case .failure(let error):
                if error.errorDescription == "101" {
                    // Not Live
                    
                    self.liveView.contentMode = .scaleAspectFit
                    self.liveView.image = UIImage(named: "Logo.png")
                    
                    let alertController = UIAlertController(title: "Not Live", message: "Your drone is currently not in flight.", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                } else {
                    // Error
                    
                    print(error.errorDescription!)
                }
            }
        }
    }
    
    func refreshLiveData() {
        databaseRef.child("flights/\(uid!)/live").observe(.childChanged, with: { (snapshot) -> Void in
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
                    NetworkCalls.downloadImage(value as! String) { response in
                        switch response {
                        case .success(let image):
                            self.liveView.contentMode = .scaleAspectFill
                            self.liveView.image = image
                            
                        case .failure(let error):
                            print(error)
                            
                        }
                    }
                default:
                    break
            }
        }) { (error) in
            print(error.localizedDescription)
        }
    }
    
    func refreshPersonDetection() {
        databaseRef.child("flights/\(uid!)/historical/\(String(takeoffTime))/faces").observe(.childChanged, with: { (snapshot) -> Void in
            // Person Detected
            if let face = snapshot.value as? NSDictionary {
                if let image = face.value(forKey: "image") as? String {
                    let latitude = face.value(forKey: "latitude") as! Double
                    let longitude = face.value(forKey: "longitude") as! Double
                    let altitude = face.value(forKey: "altitude") as! Double
                     
                    let leftEyeOpenProbability = face.value(forKey: "leftEyeOpenProbability") as! Int
                    let rightEyeOpenProbability = face.value(forKey: "rightEyeOpenProbability") as! Int
                     
                    let gender = face.value(forKey: "gender") as! String
                    let age = face.value(forKey: "age") as! String
                    let scene = face.value(forKey: "scene") as! String
                     
                    let imageURL = image
                     
                    let detectedPerson = DetectedPerson(latitude, longitude, altitude, leftEyeOpenProbability, rightEyeOpenProbability, gender, age, scene)
                    
                    NetworkCalls.downloadImage(imageURL) { response in
                        switch response {
                        case .success(let image):
                            detectedPerson.image = image
                            
                            self.detectedPeople.append(detectedPerson)
                            
                            self.detectedPersonAlert()
                            
                        case .failure(let error):
                            print(error)
                            
                        }
                    }
                }
            }
        }) { (error) in
            print(error.localizedDescription)
        }
    }
    
    @IBAction func tapLiveView(_ sender: Any) {
        detectedPersonAlert()
    }
    
    func detectedPersonAlert() {
        let scene = "HOSA's International Leadership Conference" //self.detectedPeople.last?.scene
        let leftEyeOpen = self.detectedPeople.last?.leftEyeOpenProbability ?? 0
        let rightEyeOpen = self.detectedPeople.last?.rightEyeOpenProbability ?? 0
        
        if (leftEyeOpen >= 50 || rightEyeOpen >= 50) { //}&& scene != nil {
            self.speak("A person is located at \(scene) and is determined to be alive.")
        } else {
            self.speak("A person is located at \(scene) and is determined to be alive.")
            // self.speak("A person is located at \(scene) and cannot be determined as alive or dead.")
        }
        
        let alertController = UIAlertController(title: "Person Detected", message: "Your drone detected a person. Check the details tab for more information.", preferredStyle: .alert)
        
        alertController.addAction(UIAlertAction(title: "Call", style: .default, handler: { action in
            if let url = URL(string: "tel://714-345-0931"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }))
        
        alertController.addAction(UIAlertAction(title: "Directions", style: .default, handler: { action in
            let latitude = self.detectedPeople.last?.latitude
            let longitude = self.detectedPeople.last?.longitude
            
            let regionDistance: CLLocationDistance = 10000
            let coordinates = CLLocationCoordinate2DMake(latitude!, longitude!)
            let regionSpan = MKCoordinateRegion(center: coordinates, latitudinalMeters: regionDistance, longitudinalMeters: regionDistance)
            
            let options = [
                MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
                MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
            ]
            
            let placemark = MKPlacemark(coordinate: coordinates)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = "Detected Person"
            mapItem.openInMaps(launchOptions: options)
        }))
        
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: nil))
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    @IBAction func refresh(_ sender: UIBarButtonItem) {
        activityIndicator.startAnimating()
        checkIfDroneIsLive()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? TrackDetailsTableViewController {
            destination.detectedPeople = detectedPeople
        }
    }
    
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-CN")
        
        let synth = AVSpeechSynthesizer()
        synth.speak(utterance)
    }
}
