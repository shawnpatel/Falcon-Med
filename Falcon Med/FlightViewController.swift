//
//  FlightViewController.swift
//  Dr. Drone
//
//  Created by Shawn Patel on 11/19/18.
//  Copyright © 2018 Shawn Patel. All rights reserved.
//

import UIKit

class FlightViewController: UIViewController {

    @IBOutlet weak var agree: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
