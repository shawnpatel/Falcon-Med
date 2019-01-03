//
//  AvionicsViewController.swift
//  Dr. Drone
//
//  Created by Shawn Patel on 11/18/18.
//  Copyright © 2018 Shawn Patel. All rights reserved.
//

import UIKit
import CoreML
import Vision
import CoreLocation
import CoreMotion
import MapKit
import AVFoundation

import Firebase

class AvionicsViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, AVCapturePhotoCaptureDelegate {
    
    // MARK: Declare Variables
    
    // Storyboard Outlets
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var cameraView: UIView!
    
    @IBOutlet weak var locationCoordinates: UILabel!
    
    @IBOutlet weak var zAccelPosHeight: NSLayoutConstraint!
    @IBOutlet weak var zAccelNegHeight: NSLayoutConstraint!
    
    // Timers
    var telemetryTimer: Timer!
    var cameraTimer: Timer!
    var historicalFlightDataTimer: Timer!
    
    // Location
    var locationManager: CLLocationManager!
    var currentLocation: CLLocation!
    var currentSpeed: CLLocationSpeed!
    
    // Motion
    var motionManager: CMMotionManager!
    
    // Camera
    var captureSession: AVCaptureSession!
    var stillImageOutput: AVCapturePhotoOutput!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    
    // Firebase
    var databaseRef: DatabaseReference!
    var storageRef: StorageReference!
    var uid: String!
    
    let options = VisionFaceDetectorOptions()
    lazy var vision = Vision.vision()
    
    // Global Variables
    var takeoffTime: Int!
    
    var latitude: CLLocationDegrees!
    var longitude: CLLocationDegrees!
    var altitude: CLLocationDistance!
    var speed: CLLocationSpeed!
    
    var heading: CLLocationDirection!
    
    var pitch: Double!
    var roll: Double!
    var yaw: Double!
    
    var accelX: Double!
    var accelY: Double!
    var accelZ: Double!
    
    // MARK: View Did Initiate Functions
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Setup Live Camera Preview
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium
        
        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("Unable to access back camera!")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            stillImageOutput = AVCapturePhotoOutput()
            
            if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
                captureSession.addInput(input)
                captureSession.addOutput(stillImageOutput)
                setupLivePreview()
            }
        }
        catch let error  {
            print("Error Unable to initialize back camera:  \(error.localizedDescription)")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Rotate Screen to Landscape Right
        appDelegate.deviceOrientation = .landscapeRight
        let value = UIInterfaceOrientation.landscapeRight.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
        
        // Setup Location Manager
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        
        // Setup Motion Manager
        motionManager = CMMotionManager()
        motionManager.startDeviceMotionUpdates()
        telemetryTimer = Timer.scheduledTimer(timeInterval: 0.25, target: self, selector: #selector(readTelemetry), userInfo: nil, repeats: true)
        
        // Initiate Historical Avionic Data Save
        takeoffTime = UserDefaults.standard.integer(forKey: "takeoffTime")
        historicalFlightDataTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(saveHistoricalFlightData), userInfo: nil, repeats: true)
        
        // Setup Vision Face Detector Options & Camera Timer
        options.classificationMode = .all
        options.minFaceSize = 0.05
        cameraTimer = Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(takePicture), userInfo: nil, repeats: true)
        
        // Setup Map Properties
        map.delegate = self
        map.mapType = .standard
        map.showsUserLocation = true
        map.setUserTrackingMode(.followWithHeading, animated: true)
        map.isUserInteractionEnabled = false
        map.isZoomEnabled = false
        map.isScrollEnabled = false
        
        // Initialize Firebase References and UID
        databaseRef = Database.database().reference()
        storageRef = Storage.storage().reference()
        uid = Auth.auth().currentUser?.uid
        
        // Create App Resigned Notification Center Observer
        NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    // MARK: Get Location Data
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let currentLocation = locations.last
        
        latitude = currentLocation?.coordinate.latitude ?? 0
        longitude = currentLocation?.coordinate.longitude ?? 0
        altitude = currentLocation?.altitude ?? -1 * 3.28084    // m -> ft
        speed = currentLocation?.speed ?? 0 * 2.23694  // m/s -> mph
        
        let roundedLatitude = Float(round(1000 * latitude) / 1000)
        let roundedLongitude = Float(round(1000 * longitude) / 1000)
        
        // Update UI
        locationCoordinates.text = "\(roundedLatitude), \(roundedLongitude)"
        
        // Save Location Data to Firebase
        self.databaseRef.child("flights/\(uid!)/live/location/latitude").setValue(latitude)
        self.databaseRef.child("flights/\(uid!)/live/location/longitude").setValue(longitude)
        self.databaseRef.child("flights/\(uid!)/live/location/altitude").setValue(altitude)
        self.databaseRef.child("flights/\(uid!)/live/telemetry/speed").setValue(speed)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading.trueHeading
        
        self.databaseRef.child("flights/\(uid!)/live/location/heading").setValue(heading)
    }
    
    // MARK: Get Motion Data
    
    @objc func readTelemetry() {
        if let data = motionManager.deviceMotion {
            let attitude = data.attitude
            let acceleration = data.userAcceleration
            
            pitch = attitude.pitch
            roll = attitude.roll
            yaw = attitude.yaw
            
            accelX = acceleration.x
            accelY = acceleration.y
            accelZ = acceleration.z
            
            // Update UI
            if accelZ > 0 {
                let multiplier = CGFloat(accelZ / 1)
                
                zAccelNegHeight = zAccelNegHeight.setMultiplier(0.001)
                zAccelPosHeight = zAccelPosHeight.setMultiplier(multiplier)
            } else if accelZ < 0 {
                let multiplier = CGFloat(-accelZ / 1)
                
                zAccelPosHeight = zAccelPosHeight.setMultiplier(0.001)
                zAccelNegHeight = zAccelNegHeight.setMultiplier(multiplier)
            } else {
                zAccelPosHeight = zAccelPosHeight.setMultiplier(0)
                zAccelNegHeight = zAccelNegHeight.setMultiplier(0)
            }
            
            // Save Motion Data to Firebase
            self.databaseRef.child("flights/\(uid!)/live/telemetry/pitch").setValue(pitch)
            self.databaseRef.child("flights/\(uid!)/live/telemetry/roll").setValue(roll)
            self.databaseRef.child("flights/\(uid!)/live/telemetry/yaw").setValue(yaw)
            
            self.databaseRef.child("flights/\(uid!)/live/telemetry/accelX").setValue(accelX)
            self.databaseRef.child("flights/\(uid!)/live/telemetry/accelY").setValue(accelY)
            self.databaseRef.child("flights/\(uid!)/live/telemetry/accelZ").setValue(accelZ)
        }
    }
    
    // MARK: Save Historical Flight Data
    
    @objc func saveHistoricalFlightData() {
        // Save location and telemetry data every 10 seconds.
        let timestamp = Int(NSDate().timeIntervalSince1970)
        
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/location/latitude").setValue(latitude)
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/location/longitude").setValue(longitude)
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/location/altitude").setValue(altitude)
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/location/heading").setValue(heading)
        
        // Should we save telemetric data historically?
        /*self.ref.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/telemetry/speed").setValue(speed)
        
        self.ref.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/telemetry/pitch").setValue(pitch)
        self.ref.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/telemetry/roll").setValue(roll)
        self.ref.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/telemetry/yaw").setValue(yaw)
        
        self.ref.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/telemetry/accelX").setValue(accelZ)
        self.ref.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/telemetry/accelY").setValue(accelY)
        self.ref.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/telemetry/accelZ").setValue(accelZ)*/
    }
    
    // MARK: Camera Live View
    
    func setupLivePreview() {
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspect
        videoPreviewLayer.connection?.videoOrientation = .landscapeRight
        cameraView.layer.addSublayer(videoPreviewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
            
            DispatchQueue.main.async {
                self.videoPreviewLayer.videoGravity = .resizeAspectFill
                self.videoPreviewLayer.frame = self.cameraView.bounds
            }
        }
    }
    
    @objc func takePicture() {
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation() else {
            return
        }
        
        let rawImage = UIImage(data: imageData)?.cgImage
        let orientedImage = UIImage(cgImage: rawImage!, scale: 1, orientation: .up)
        
        detectFaceIn(image: orientedImage)
    }
    
    // MARK: Image Analysis
    
    func detectFaceIn(image: UIImage) {
        // Function Global Variables
        var leftEyeOpenProbability: CGFloat = 0
        var rightEyeOpenProbability: CGFloat = 0
        
        let visionImage = VisionImage(image: image)
        
        // Facial and Environment Recognition Detectors
        let faceDetector = vision.faceDetector(options: options)
        
        faceDetector.process(visionImage) { faces, error in
            guard error == nil, let faces = faces, !faces.isEmpty else {
                print(error?.localizedDescription ?? "No Face Detected")
                return
            }
            
            // Faces Detected
            for face in faces {
                if face.hasLeftEyeOpenProbability {
                    leftEyeOpenProbability = face.leftEyeOpenProbability
                }
                
                if face.hasRightEyeOpenProbability {
                    rightEyeOpenProbability = face.rightEyeOpenProbability
                }
            }
        }
        
        if leftEyeOpenProbability != 0 || rightEyeOpenProbability != 0 {
            self.saveFaceDetectedLocationData(leftEyeOpenProbability: leftEyeOpenProbability, rightEyeOpenProbability: rightEyeOpenProbability, image: image)
        }
    }
    
    // Save Image and Relevant Data Once Face is Detected
    func saveFaceDetectedLocationData(leftEyeOpenProbability: CGFloat, rightEyeOpenProbability: CGFloat, image: UIImage) {
        let timestamp = Int(NSDate().timeIntervalSince1970)
        
        let imageData = image.pngData()
        let imageRef = storageRef.child("\(uid!)/\(takeoffTime!)/\(timestamp).png")

        imageRef.putData(imageData!, metadata: nil) { (metadata, error) in
            guard let metadata = metadata else {
                print(error?.localizedDescription ?? "Image Upload Error")
                return
            }
            
            let size = metadata.size
            print(size)
            
            imageRef.downloadURL { (url, error) in
                guard let downloadURL = url else {
                    print(error?.localizedDescription ?? "Unable to Access Download URL")
                    return
                }
                
                self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(timestamp)/image").setValue(downloadURL.absoluteString)
            }
        }
        
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/faces/\(timestamp)/location/latitude").setValue(latitude)
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/faces/\(timestamp)/location/longitude").setValue(longitude)
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/faces/\(timestamp)/location/altitude").setValue(altitude)
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/faces/\(timestamp)/location/heading").setValue(heading)
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/faces/\(timestamp)/location/leftEyeOpenProbability").setValue(leftEyeOpenProbability)
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/faces/\(timestamp)/location/rightEyeOpenProbability").setValue(rightEyeOpenProbability)
    }
    
    // TODO: Scene + Gender + Age Classification
    /*func coreMLAnalyze(image: UIImage, model: MLModel) -> String {
        guard let model = try? VNCoreMLModel(for: model) else {
            fatalError("Can't load MobileNet model.")
        }
        
        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let results = request.results as? [VNClassificationObservation], let topResult = results.first else {
                fatalError("Unexpected result type from VNCoreMLRequest.")
            }
            
            let items = topResult.identifier.components(separatedBy: ", ")
            //return items[0].capitalized
        }
        
        let handler = VNImageRequestHandler(ciImage: CIImage(image: image)!)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
        }
    }*/
    
    // MARK: Garbage Collection
    
    @objc func willResignActive(_ notification: Notification) {
        terminate()
        
        terminateHistorical()
        
        navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        terminate()
        
        terminateHistorical()
        
        navigationController?.popToRootViewController(animated: true)
    }
    
    @IBAction func done(_ sender: UIBarButtonItem) {
        terminate()
        
        // TODO: Navigate to Flight Summary View
        navigationController?.popToRootViewController(animated: true)
    }
    
    func terminate() {
        tabBarController?.tabBar.isHidden = false
        
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
        
        motionManager.stopDeviceMotionUpdates()
        
        captureSession.stopRunning()
        
        telemetryTimer.invalidate()
        cameraTimer.invalidate()
        historicalFlightDataTimer.invalidate()
        
        appDelegate.deviceOrientation = .portrait
        let value = UIInterfaceOrientation.portrait.rawValue
        UIDevice.current.setValue(value, forKey: "orientation")
        
        self.databaseRef.child("flights/\(uid!)/live").removeValue()
    }
    
    func terminateHistorical() {
        // Delete Historical Flight Data
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)").removeValue()
        
        var localTakeoffTime = takeoffTime!
        let timestamp = Int(NSDate().timeIntervalSince1970)
        
        while localTakeoffTime <= timestamp {
            // Delete Pictures of Faces
            let facesRef = storageRef.child("\(uid!)/\(takeoffTime!)/\(localTakeoffTime).png")
            facesRef.delete { error in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    // File Successfully Deleted
                }
            }
            
            localTakeoffTime += 1
        }
    }
}

extension NSLayoutConstraint {
    func setMultiplier(_ multiplier: CGFloat) -> NSLayoutConstraint {
        NSLayoutConstraint.deactivate([self])
        
        let newConstraint = NSLayoutConstraint(
            item: firstItem!,
            attribute: firstAttribute,
            relatedBy: relation,
            toItem: secondItem,
            attribute: secondAttribute,
            multiplier: multiplier,
            constant: constant)
        
        newConstraint.priority = priority
        newConstraint.shouldBeArchived = self.shouldBeArchived
        newConstraint.identifier = self.identifier
        
        NSLayoutConstraint.activate([newConstraint])
        
        return newConstraint
    }
}
