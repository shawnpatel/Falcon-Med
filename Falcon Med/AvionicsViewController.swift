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
import LMGaugeView

import Firebase

class AvionicsViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, AVCapturePhotoCaptureDelegate {
    
    // MARK: Declare Variables
    
    // Storyboard Outlets
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var cameraView: UIView!
    
    @IBOutlet weak var coordinatesLabel: UILabel!
    @IBOutlet weak var altitudeLabel: UILabel!
    @IBOutlet weak var speedGauge: LMGaugeView!
    
    @IBOutlet weak var accelXLabel: UILabel!
    @IBOutlet weak var accelYLabel: UILabel!
    @IBOutlet weak var accelZLabel: UILabel!
    
    @IBOutlet weak var xAccelPosHeight: NSLayoutConstraint!
    @IBOutlet weak var xAccelNegHeight: NSLayoutConstraint!
    
    @IBOutlet weak var yAccelPosHeight: NSLayoutConstraint!
    @IBOutlet weak var yAccelNegHeight: NSLayoutConstraint!
    
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
    var timestamp: Int!
    
    var latitude: Double!
    var longitude: Double!
    var altitude: Double!
    var speed: Double!
    
    var heading: Double!
    
    var accelX: Double!
    var accelY: Double!
    var accelZ: Double!
    
    var numberOfDetectedPeople: Int!
    var detectedPersonLatitude: [Double]!
    var detectedPersonLongitude: [Double]!
    var detectedPersonAltitude: [Double]!
    var detectedPersonLeftEyeOpen: [Int]!
    var detectedPersonRightEyeOpen: [Int]!
    var detectedPersonGender: [String]!
    var detectedPersonAge: [String]!
    var detectedPersonScene: [String]!
    
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
        
        // Initialize Variables
        numberOfDetectedPeople = 0
        detectedPersonLatitude = []
        detectedPersonLongitude = []
        detectedPersonAltitude = []
        detectedPersonLeftEyeOpen = []
        detectedPersonRightEyeOpen = []
        detectedPersonGender = []
        detectedPersonAge = []
        detectedPersonScene = []
        
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
        map.isUserInteractionEnabled = true
        map.isZoomEnabled = false
        map.isScrollEnabled = true
        map.isPitchEnabled = false
        map.isRotateEnabled = false
        
        // Setup Speed Gauge Properties
        speedGauge.minValue = 0
        speedGauge.maxValue = 10
        speedGauge.valueFont = UIFont.systemFont(ofSize: 33, weight: .semibold)
        speedGauge.unitOfMeasurementFont = UIFont.systemFont(ofSize: 9, weight: .regular)
        
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
        
        let localLatitude = currentLocation?.coordinate.latitude ?? 0
        let localLongitude = currentLocation?.coordinate.longitude ?? 0
        let localAltitude = currentLocation?.altitude ?? -1 * 3.28084    // m -> ft
        let localSpeed = currentLocation?.speed ?? 0 * 2.23694    // m/s -> mph
        
        latitude = Double(localLatitude).roundTo(places: 3)
        longitude = Double(localLongitude).roundTo(places: 3)
        altitude = Double(localAltitude).roundTo(places: 2)
        speed = Double(localSpeed).roundTo(places: 2)
        
        // Update UI
        coordinatesLabel.text = "\(latitude!), \(longitude!)"
        altitudeLabel.text = "\(altitude!) FT"
        speedGauge.value = CGFloat(speed)
        
        // Save Location Data to Firebase
        self.databaseRef.child("flights/\(uid!)/live/location/latitude").setValue(latitude)
        self.databaseRef.child("flights/\(uid!)/live/location/longitude").setValue(longitude)
        self.databaseRef.child("flights/\(uid!)/live/location/altitude").setValue(altitude)
        self.databaseRef.child("flights/\(uid!)/live/telemetry/speed").setValue(speed)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let localHeading = newHeading.trueHeading
        
        heading = Double(localHeading).rounded()
        
        self.databaseRef.child("flights/\(uid!)/live/location/heading").setValue(heading)
    }
    
    // MARK: Get Motion Data
    
    @objc func readTelemetry() {
        if let data = motionManager.deviceMotion {
            let acceleration = data.userAcceleration
            
            // Units: [Gs]
            accelX = Double(acceleration.y).roundTo(places: 2)    // Since device is landscape, x-axis is portrait y-xais.
            accelY = Double(acceleration.x).roundTo(places: 2)    // Since device is landscape, y-axis is portrait x-axis.
            accelZ = Double(acceleration.z).roundTo(places: 2)
            
            // Update UI
            accelXLabel.text = "\(accelX!) Gs"
            accelYLabel.text = "\(accelY!) Gs"
            accelZLabel.text = "\(accelZ!) Gs"
            
            if accelX > 0 {
                let multiplier = CGFloat(accelX / 1)
                
                xAccelNegHeight = xAccelNegHeight.cloneMultiplier(0.001)
                xAccelPosHeight = xAccelPosHeight.cloneMultiplier(multiplier)
            } else if accelX < 0 {
                let multiplier = CGFloat(-accelX / 1)
                
                xAccelPosHeight = xAccelPosHeight.cloneMultiplier(0.001)
                xAccelNegHeight = xAccelNegHeight.cloneMultiplier(multiplier)
            } else {
                xAccelPosHeight = xAccelPosHeight.cloneMultiplier(0.001)
                xAccelNegHeight = xAccelNegHeight.cloneMultiplier(0.001)
            }
            
            if accelY > 0 {
                let multiplier = CGFloat(accelY / 1)
                
                yAccelNegHeight = yAccelNegHeight.cloneMultiplier(0.001)
                yAccelPosHeight = yAccelPosHeight.cloneMultiplier(multiplier)
            } else if accelY < 0 {
                let multiplier = CGFloat(-accelY / 1)
                
                yAccelPosHeight = yAccelPosHeight.cloneMultiplier(0.001)
                yAccelNegHeight = yAccelNegHeight.cloneMultiplier(multiplier)
            } else {
                yAccelPosHeight = yAccelPosHeight.cloneMultiplier(0.001)
                yAccelNegHeight = yAccelNegHeight.cloneMultiplier(0.001)
            }
            
            if accelZ > 0 {
                let multiplier = CGFloat(accelZ / 1)
                
                zAccelNegHeight = zAccelNegHeight.cloneMultiplier(0.001)
                zAccelPosHeight = zAccelPosHeight.cloneMultiplier(multiplier)
            } else if accelZ < 0 {
                let multiplier = CGFloat(-accelZ / 1)
                
                zAccelPosHeight = zAccelPosHeight.cloneMultiplier(0.001)
                zAccelNegHeight = zAccelNegHeight.cloneMultiplier(multiplier)
            } else {
                zAccelPosHeight = zAccelPosHeight.cloneMultiplier(0.001)
                zAccelNegHeight = zAccelNegHeight.cloneMultiplier(0.001)
            }
            
            // Save Motion Data to Firebase
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
        var leftEyeOpenProbability: Int = 0
        var rightEyeOpenProbability: Int = 0
        
        let visionImage = VisionImage(image: image)
        
        // Facial and Environment Recognition Detectors
        let faceDetector = vision.faceDetector(options: options)
        
        faceDetector.process(visionImage) { faces, error in
            guard error == nil, let faces = faces, !faces.isEmpty else {
                print(error?.localizedDescription ?? "No Face Detected")
                
                self.detectSceneIn(image: image, toUpdate: "updateUI")
                return
            }
            
            // Faces Detected
            print("Face Detected")
            let face = faces.first!
            
            if face.hasLeftEyeOpenProbability {
                leftEyeOpenProbability = Int(Double(face.leftEyeOpenProbability).roundTo(places: 2) * 100)
            }
            
            if face.hasRightEyeOpenProbability {
                rightEyeOpenProbability = Int(Double(face.rightEyeOpenProbability).roundTo(places: 2) * 100)
            }
            
            self.timestamp = Int(NSDate().timeIntervalSince1970)
            
            // Upload Image
            self.uploadFaceImage(image)
            
            // Save Location Data
            self.detectedPersonLatitude.append(self.latitude)
            self.detectedPersonLongitude.append(self.longitude)
            self.detectedPersonAltitude.append(self.altitude)
            
            self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/location/latitude").setValue(self.latitude)
            self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/location/longitude").setValue(self.longitude)
            self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/location/altitude").setValue(self.altitude)
            
            // Save Eye Data
            self.detectedPersonLeftEyeOpen.append(leftEyeOpenProbability)
            self.detectedPersonRightEyeOpen.append(rightEyeOpenProbability)
            
            self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/leftEyeOpenProbability").setValue(leftEyeOpenProbability)
            self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/rightEyeOpenProbability").setValue(rightEyeOpenProbability)
            
            // Run Vision Algorithms
            self.detectSceneIn(image: image, toUpdate: "face")
            self.detectGenderIn(image: image)
            self.detectAgeIn(image: image)
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MKPointAnnotation else {return nil}
        
        let identifier = "MyPin"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView!.canShowCallout = true
            
            let index = Int(String((annotation.title!?.suffix(1))!))! - 1
            
            let label = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
            label.font = UIFont.systemFont(ofSize: 10)
            
            label.text = """
            Coord: \(detectedPersonLatitude[index]), \(detectedPersonLongitude[index])\n
            Altitude: \(detectedPersonAltitude[index]) FT\n
            Left Eye Open: \(detectedPersonLeftEyeOpen[index])%\n
            Right Eye Open: \(detectedPersonRightEyeOpen[index])%\n
            Gender: \(detectedPersonGender[index])\n
            Age: \(detectedPersonAge[index])\n
            Scene: \(detectedPersonScene[index])
            """
            
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
    
    // Save Image and Relevant Data Once Face is Detected
    func uploadFaceImage(_ image: UIImage) {
        let imageData = image.pngData()
        let imageRef = storageRef.child("\(uid!)/\(takeoffTime!)/\(timestamp!).png")

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
                
                self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/image").setValue(downloadURL.absoluteString)
            }
        }
    }
    
    func detectSceneIn(image: UIImage, toUpdate: String) {
        guard let model = try? VNCoreMLModel(for: GoogLeNetPlaces().model) else {
            fatalError("Can't load MobileNet model.")
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNClassificationObservation], let topResult = results.first else {
                fatalError("Unexpected result type from VNCoreMLRequest.")
            }
            
            let scenes = topResult.identifier.components(separatedBy: ", ")
            let scene = scenes[0].replacingOccurrences(of: "_", with: " ").capitalized
            
            // Save Data or Update UI
            if toUpdate == "face" {
                self.detectedPersonScene.append(scene)
                self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/scene").setValue(scene)
            } else if toUpdate == "updateUI" {
                self.databaseRef.child("flights/\(self.uid!)/live/location/scene").setValue(scene)
            }
        }
        
        let handler = VNImageRequestHandler(ciImage: CIImage(image: image)!)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
        }
    }
    
    func detectGenderIn(image: UIImage) {
        guard let model = try? VNCoreMLModel(for: GenderNet().model) else {
            fatalError("Can't load MobileNet model.")
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNClassificationObservation], let topResult = results.first else {
                fatalError("Unexpected result type from VNCoreMLRequest.")
            }
            
            let genders = topResult.identifier.components(separatedBy: ", ")
            let gender = genders[0].capitalized
            
            // Save Data
            self.detectedPersonGender.append(gender)
            self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/gender").setValue(gender)
        }
        
        let handler = VNImageRequestHandler(ciImage: CIImage(image: image)!)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
        }
    }
    
    func detectAgeIn(image: UIImage) {
        guard let model = try? VNCoreMLModel(for: AgeNet().model) else {
            fatalError("Can't load MobileNet model.")
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNClassificationObservation], let topResult = results.first else {
                fatalError("Unexpected result type from VNCoreMLRequest.")
            }
            
            let ages = topResult.identifier.components(separatedBy: ", ")
            let age = ages[0].capitalized
            
            // Save Data
            self.detectedPersonAge.append(age)
            self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/age").setValue(age)
            
            // Add Pin to Map
            self.numberOfDetectedPeople += 1
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(self.latitude), longitude: CLLocationDegrees(self.longitude))
            annotation.title = "Person \(self.numberOfDetectedPeople!)"
            self.map.addAnnotation(annotation)
        }
        
        let handler = VNImageRequestHandler(ciImage: CIImage(image: image)!)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                print(error)
            }
        }
    }
    
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
    
    @IBAction func flightLanded(_ sender: UIBarButtonItem) {
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
    func cloneMultiplier(_ multiplier: CGFloat) -> NSLayoutConstraint {
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

extension Double {
    func roundTo(places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension UILabel {
    func setLineHeight(_ lineHeight: CGFloat) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1.0
        paragraphStyle.lineHeightMultiple = lineHeight
        paragraphStyle.alignment = self.textAlignment
        
        let attrString = NSMutableAttributedString()
        if (self.attributedText != nil) {
            attrString.append( self.attributedText!)
        } else {
            attrString.append( NSMutableAttributedString(string: self.text!))
            attrString.addAttribute(NSAttributedString.Key.font, value: self.font, range: NSMakeRange(0, attrString.length))
        }
        attrString.addAttribute(NSAttributedString.Key.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, attrString.length))
        self.attributedText = attrString
    }
}
