//
//  ViewController.swift
//  Dr. Drone
//
//  Created by Shawn Patel on 11/18/18.
//  Copyright © 2018 Shawn Patel. All rights reserved.
//

import UIKit
import LocalAuthentication

import Firebase
import GoogleSignIn

class LoginViewController: UIViewController, GIDSignInUIDelegate {

    @IBOutlet weak var GoogleSignInButton: GIDSignInButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        GIDSignIn.sharedInstance()?.uiDelegate = self
        
        GoogleSignInButton.style = .wide
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if Auth.auth().currentUser != nil {
            let myContext = LAContext()
            let myLocalizedReasonString = "Login quickly and securely."
            
            var authError: NSError?
            if #available(iOS 8.0, macOS 10.12.1, *) {
                if myContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
                    myContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: myLocalizedReasonString) { success, evaluateError in
                        if success {
                            // User authenticated successfully, take appropriate action
                            
                            DispatchQueue.main.async {
                                let rootVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "TabBarController") as UIViewController
                                rootVC.modalPresentationStyle = .custom
                                rootVC.modalTransitionStyle = .crossDissolve
                                self.present(rootVC, animated: true, completion: nil)
                            }
                        } else {
                            // User did not authenticate successfully, look at error and take appropriate action
                        }
                    }
                } else {
                    // Could not evaluate policy; look at authError and present an appropriate message to user
                }
            } else {
                // Fallback on earlier versions
            }
        }
    }
}

