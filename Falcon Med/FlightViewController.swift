//
//  FlightViewController.swift
//  Dr. Drone
//
//  Created by Shawn Patel on 11/19/18.
//  Copyright © 2018 Shawn Patel. All rights reserved.
//

import UIKit

import Firebase

class FlightViewController: UIViewController {

    @IBOutlet weak var agree: UISwitch!
    
    // Firebase
    var databaseRef: DatabaseReference!
    var uid: String!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.databaseRef.child("flights/\(uid!)/live").removeValue()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize Firebase References and UID
        databaseRef = Database.database().reference()
        uid = Auth.auth().currentUser?.uid
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        agree.isOn = false
    }
    
    @IBAction func beginFlight(_ sender: UIBarButtonItem) {
        if agree.isOn {
            tabBarController?.tabBar.isHidden = true
        
            let takeoffTime = Int(NSDate().timeIntervalSince1970)
            UserDefaults.standard.set(takeoffTime, forKey: "takeoffTime")
            
            self.performSegue(withIdentifier: "flightToAvionics", sender: self)
        } else {
            let alertController = UIAlertController(title: "Agree to the Terms", message: "The flight cannot begin until you agree to follow the terms displayed.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    @IBAction func getHelp(_ sender: UIBarButtonItem) {
        if let url = NSURL(string: "https://www.faa.gov/uas") {
            UIApplication.shared.open(url as URL, options: [:], completionHandler: nil)
        }
    }
}
