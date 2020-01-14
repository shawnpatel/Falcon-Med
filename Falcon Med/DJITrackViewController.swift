//
//  DJITrackViewController.swift
//  Falcon Med
//
//  Created by Shawn Patel on 5/27/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import UIKit

import DJISDK
import DJIWidget

class DJITrackViewController: UIViewController, DJIVideoFeedListener, DJISDKManagerDelegate, DJICameraDelegate, DJIBaseProductDelegate {

    @IBOutlet weak var liveCameraView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        registerApp()
    }
    
    func registerApp() {
        DJISDKManager.registerApp(with: self)
        
        productConnected(DJISDKManager.product())
    }
    
    func appRegisteredWithError(_ error: Error?) {
        if error == nil {
            showAlertView(withTitle: "Register App", withMessage: "App registered successfully.")
        } else {
            showAlertView(withTitle: "Register App", withMessage: "App was not able to register. Check App Key and network connection.")
        }
    }
    
    func videoFeed(_ videoFeed: DJIVideoFeed, didUpdateVideoData videoData: Data) {
        videoData.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) in
            let p = UnsafeMutablePointer<UInt8>.init(mutating: ptr)
            DJIVideoPreviewer.instance().push(p, length: Int32(videoData.count))
        }
    }
    
    func setupVideoPreviewer() {
        DJIVideoPreviewer.instance()?.setView(liveCameraView)
        let product = DJISDKManager.product()
        
        if product?.model == DJIAircraftModelNameA3 || product?.model == DJIAircraftModelNameN3 || product?.model == DJIAircraftModelNameMatrice600 || product?.model == DJIAircraftModelNameMatrice600Pro {
            DJISDKManager.videoFeeder()?.secondaryVideoFeed.add(self, with: nil)
        } else {
            DJISDKManager.videoFeeder()?.primaryVideoFeed.add(self, with: nil)
        }
        
        DJIVideoPreviewer.instance().start()
    }
    
    func resetVideoPreview() {
        DJIVideoPreviewer.instance().unSetView()
        let product = DJISDKManager.product()
        
        if product?.model == DJIAircraftModelNameA3 || product?.model == DJIAircraftModelNameN3 || product?.model == DJIAircraftModelNameMatrice600 || product?.model == DJIAircraftModelNameMatrice600Pro {
            DJISDKManager.videoFeeder()?.secondaryVideoFeed.remove(self)
        } else {
            DJISDKManager.videoFeeder()?.primaryVideoFeed.remove(self)
        }
    }
    
    func fetchCamera() -> DJICamera? {
        if DJISDKManager.product() == nil {
            return nil
        }
        
        if DJISDKManager.product() is DJIAircraft {
             return (DJISDKManager.product() as? DJIAircraft)?.camera
        } else if DJISDKManager.product() is DJIHandheld {
            return (DJISDKManager.product() as? DJIHandheld)?.camera
        }
        
        return nil
    }
    
    func productConnected(_ product: DJIBaseProduct?) {
        if product != nil {
            product?.delegate = self
            let camera = fetchCamera()
            
            if camera != nil {
                camera?.delegate = self
            }
            
            setupVideoPreviewer()
        }
    }
    
    func productDisconnected() {
        let camera = fetchCamera()
        
        if camera != nil && camera?.delegate != nil {
            camera?.delegate = nil
        }
        
        resetVideoPreview()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        let camera = fetchCamera()
        
        if camera != nil && camera?.delegate != nil {
            camera?.delegate = nil
        }
        
        resetVideoPreview()
    }
    
    func showAlertView(withTitle title: String, withMessage message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        
        present(alert, animated: true)
    }
}
