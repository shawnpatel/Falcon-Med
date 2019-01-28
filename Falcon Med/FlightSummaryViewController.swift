//
//  FlightSummaryViewController.swift
//  Falcon Med
//
//  Created by Shawn Patel on 1/28/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import UIKit
import MapKit

import Firebase

class FlightSummaryViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var map: MKMapView!
    
    // Firebase
    var databaseRef: DatabaseReference!
    var uid: String!
    
    var detectedPeople: [DetectedPerson]!
    var historicalData: [HistoricalData]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup Map Properties
        map.delegate = self
        map.mapType = .standard
        map.showsUserLocation = true
        
        // Initialize Firebase References and UID
        databaseRef = Database.database().reference()
        uid = Auth.auth().currentUser?.uid
    }
    
    func downloadData() {
        databaseRef.child("flights").child(uid).observeSingleEvent(of: .value, with: { (snapshot) in
            let value = snapshot.value as? NSDictionary
            print(value!)
            
            // TODO: Parse Historical and Detected Faces Data and Add Pins to Maps
            
            // Add Pin to Map
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(0/*INPUT LATITUDE*/), longitude: CLLocationDegrees(0/*INPUT LONGITUDE*/))
            annotation.title = "" // Person: <Number of Person> || Historical: <Timestamp>
            self.map.addAnnotation(annotation)
        }) { (error) in
            print(error.localizedDescription)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MKPointAnnotation else {return nil}
        
        let identifier = "MyPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView!.canShowCallout = true
            
            let title = annotation.title as? String
            let index = Int(String((annotation.title!?.suffix(1))!))! - 1
            
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
            label.font = UIFont.systemFont(ofSize: 10)
            
            if title!.range(of: "Person") != nil {
                label.text = """
                Coord: \(detectedPeople[index].latitude), \(detectedPeople[index].longitude)\n
                Altitude: \(detectedPeople[index].altitude) FT\n
                Left Eye Open: \(detectedPeople[index].leftEyeOpenProbability)%\n
                Right Eye Open: \(detectedPeople[index].rightEyeOpenProbability)%\n
                Gender: \(detectedPeople[index].gender)\n
                Age: \(detectedPeople[index].age)\n
                Scene: \(detectedPeople[index].scene)
                """
            } else if title!.range(of: "Historical") != nil {
                label.text = """
                Timestamp: \(historicalData[index].timestamp)\n
                Coord: \(historicalData[index].latitude), \(historicalData[index].longitude)\n
                Altitude: \(historicalData[index].altitude) FT\n
                Heading: \(historicalData[index].heading) °\n
                """
            }
            
            label.setLineHeight(0.5)
            label.numberOfLines = 0
            annotationView?.detailCalloutAccessoryView = label
            
            let width = NSLayoutConstraint(item: label, attribute: .width, relatedBy: .lessThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 200)
            label.addConstraint(width)
            
            let height = NSLayoutConstraint(item: label, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 100)
            label.addConstraint(height)
        } else {
            annotationView!.annotation = annotation
        }
        
        return annotationView
    }
}
