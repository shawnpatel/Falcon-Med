//
//  FlightViewController.swift
//  Dr. Drone
//
//  Created by Shawn Patel on 11/19/18.
//  Copyright © 2018 Shawn Patel. All rights reserved.
//

import UIKit

class FlightViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func beginFlight(_ sender: UIButton) {
        tabBarController?.tabBar.isHidden = true
        
        let takeoffTime = Int(NSDate().timeIntervalSince1970)
        UserDefaults.standard.set(takeoffTime, forKey: "takeoffTime")
    }
}
