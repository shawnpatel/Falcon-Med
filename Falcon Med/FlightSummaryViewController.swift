//
//  FlightSummaryViewController.swift
//  Falcon Med
//
//  Created by Shawn Patel on 1/28/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import UIKit
import MapKit

class FlightSummaryViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var map: MKMapView!
    
    // Global Variables
    var detectedPeople: [DetectedPerson]!
    var historicalData: [HistoricalData]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup Map Properties
        map.delegate = self
        map.mapType = .hybrid
        map.showsUserLocation = true
        map.setUserTrackingMode(.follow, animated: true)
        
        if detectedPeople == nil {
            detectedPeople = []
        }
        
        if historicalData == nil {
            historicalData = []
        }
        
        addMapAnnotations()
    }
    
    func addMapAnnotations() {
        var personIndex = 1
        for person in detectedPeople {
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(person.latitude), longitude: CLLocationDegrees(person.longitude))
            annotation.title = "Person \(personIndex)"
            self.map.addAnnotation(annotation)
            
            personIndex += 1
        }
        
        var historicalIndex = 1
        for data in historicalData {
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(data.latitude), longitude: CLLocationDegrees(data.longitude))
            annotation.title = "Historical \(historicalIndex)"
            self.map.addAnnotation(annotation)
            
            historicalIndex += 1
        }
        
        self.map.showAnnotations(self.map.annotations, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? FlightSummaryDetailsTableViewController {
            destination.detectedPeople = detectedPeople
            destination.historicalData = historicalData
        }
    }
}
