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
import LMGaugeView

class AvionicsViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, AVCapturePhotoCaptureDelegate {
    
    // MARK: Declare Variables
    
    // Storyboard Outlets
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var cameraView: UIView!
    
    @IBOutlet weak var coordinatesLabel: UILabel!
    @IBOutlet weak var altitudeLabel: UILabel!
    @IBOutlet weak var speedGauge: LMGaugeView!
    
    @IBOutlet weak var accelerationGraph: UIImageView!
    @IBOutlet weak var accelerationPoint: UIImageView!
    
    @IBOutlet weak var accelerationPointWidth: NSLayoutConstraint!
    @IBOutlet weak var accelerationPointHeight: NSLayoutConstraint!
    
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
    
    var detectedPeople: [DetectedPerson]!
    var historicalData: [HistoricalData]!
    
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
        detectedPeople = []
        historicalData = []
        
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
        self.databaseRef.child("flights/\(uid!)/live/latitude").setValue(latitude)
        self.databaseRef.child("flights/\(uid!)/live/longitude").setValue(longitude)
        self.databaseRef.child("flights/\(uid!)/live/altitude").setValue(altitude)
        self.databaseRef.child("flights/\(uid!)/live/speed").setValue(speed)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let localHeading = newHeading.trueHeading
        
        heading = Double(localHeading).rounded()
        
        self.databaseRef.child("flights/\(uid!)/live/heading").setValue(heading)
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
            /*let maxAccel = Double(1)
            
            let graphCenterX = Double(accelerationGraph.center.x)
            let graphCenterY = Double(accelerationGraph.center.y)
            
            let graphWidth = Double(accelerationGraph.frame.width / 2)
            let graphHeight = Double(accelerationGraph.frame.height / 2)
            
            let pointCenterX = Double(accelerationPoint.center.x)
            let pointCenterY = Double(accelerationPoint.center.y)
            
            let accelerationPointDiameter = Double(accelerationPointWidth.constant)
            
            if accelX > 0 {
                let deltaX = graphCenterX + (graphWidth * (accelX / maxAccel))
                accelerationPoint.center = CGPoint(x: deltaX, y: pointCenterY)
            } else if accelX < 0 {
                let deltaX = graphCenterX - (graphWidth * (-accelX / maxAccel))
                accelerationPoint.center = CGPoint(x: deltaX, y: pointCenterY)
            } else {
                accelerationPoint.center = CGPoint(x: graphCenterX, y: pointCenterY)
            }
            
            if accelY > 0 {
                let deltaY = graphCenterY + (graphHeight * (accelY / maxAccel))
                accelerationPoint.center = CGPoint(x: pointCenterX, y: deltaY)
            } else if accelY < 0 {
                let deltaY = graphCenterY - (graphHeight * (-accelY / maxAccel))
                accelerationPoint.center = CGPoint(x: pointCenterX, y: deltaY)
            } else {
                accelerationPoint.center = CGPoint(x: pointCenterY, y: graphCenterY)
            }
            
            if accelZ > 0 {
                let diameter = CGFloat(accelerationPointDiameter + (accelerationPointDiameter * (accelZ / maxAccel)))
                accelerationPointWidth.constant = diameter
                accelerationPointHeight.constant = diameter
            } else if accelZ < 0 {
                let diameter = CGFloat(accelerationPointDiameter - (accelerationPointDiameter * (-accelZ / maxAccel)))
                accelerationPointWidth.constant = diameter
                accelerationPointHeight.constant = diameter
            } else {
                accelerationPointWidth.constant = 25
                accelerationPointHeight.constant = 25
            }*/
            
            // Save Motion Data to Firebase
            self.databaseRef.child("flights/\(uid!)/live/accelX").setValue(accelX)
            self.databaseRef.child("flights/\(uid!)/live/accelY").setValue(accelY)
            self.databaseRef.child("flights/\(uid!)/live/accelZ").setValue(accelZ)
        }
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
                
                let sceneAnalysis = ImageAnalysis(model: GoogLeNetPlaces().model, image: image)
                sceneAnalysis.detect(completion: { (error, scene) in
                    if error != nil {
                        self.databaseRef.child("flights/\(self.uid!)/live/scene").setValue(scene)
                    }
                })
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
            
            // Save Data
            let detectedPerson = DetectedPerson(self.latitude, self.longitude, self.altitude, leftEyeOpenProbability, rightEyeOpenProbability)
            detectedPerson.image = image
            self.detectedPeople.append(detectedPerson)
            
            self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/latitude").setValue(self.latitude)
            self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/longitude").setValue(self.longitude)
            self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/altitude").setValue(self.altitude)
            
            self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/leftEyeOpenProbability").setValue(leftEyeOpenProbability)
            self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/rightEyeOpenProbability").setValue(rightEyeOpenProbability)
            
            // Add Pin to Map
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: CLLocationDegrees(self.latitude), longitude: CLLocationDegrees(self.longitude))
            annotation.title = "Person \(self.detectedPeople.count)"
            self.map.addAnnotation(annotation)
            
            // Run Vision Algorithms
            self.runImageAnalysis(image: image)
        }
    }
    
    // Upload Image Once Face is Detected
    func uploadFaceImage(_ image: UIImage) {
        let imageData = image.pngData()
        let imageRef = storageRef.child("\(uid!)/\(takeoffTime!)/\(timestamp!).png")

        imageRef.putData(imageData!, metadata: nil) { (metadata, error) in
            guard metadata != nil else {
                print(error?.localizedDescription ?? "Image Upload Error")
                return
            }
            
            imageRef.downloadURL { (url, error) in
                guard let downloadURL = url else {
                    print(error?.localizedDescription ?? "Unable to Access Download URL")
                    return
                }
                
                self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/image").setValue(downloadURL.absoluteString)
            }
        }
    }
    
    func runImageAnalysis(image: UIImage) {
        let sceneAnalysis = ImageAnalysis(model: GoogLeNetPlaces().model, image: image)
        sceneAnalysis.detect(completion: { (error, scene) in
            if error == nil {
                // Save Data
                self.detectedPeople.last?.scene = scene!
                self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/scene").setValue(scene)
            }
        })
        
        let genderAnalysis = ImageAnalysis(model: GenderNet().model, image: image)
        genderAnalysis.detect(completion: { (error, gender) in
            if error == nil {
                // Save Data
                self.detectedPeople.last?.gender = gender!
                self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/gender").setValue(gender)
            }
        })
        
        let ageAnalysis = ImageAnalysis(model: AgeNet().model, image: image)
        ageAnalysis.detect(completion: { (error, age) in
            if error == nil {
                // Save Data
                self.detectedPeople.last?.age = age!
                self.databaseRef.child("flights/\(self.uid!)/historical/\(self.takeoffTime!)/faces/\(self.timestamp!)/age").setValue(age)
            }
        })
    }
    
    // MARK: Save Historical Flight Data
    
    @objc func saveHistoricalFlightData() {
        // Save location and telemetry data every 10 seconds.
        let timestamp = Int(NSDate().timeIntervalSince1970)
        
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/latitude").setValue(latitude)
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/longitude").setValue(longitude)
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/altitude").setValue(altitude)
        self.databaseRef.child("flights/\(uid!)/historical/\(takeoffTime!)/\(timestamp)/heading").setValue(heading)
        
        let historicalData = HistoricalData(timestamp, latitude, longitude, altitude, heading)
        self.historicalData.append(historicalData)
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
        
        self.performSegue(withIdentifier: "avionicsToFlightSummary", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "avionicsToFlightSummary" {
            if let destination = segue.destination as? FlightSummaryViewController {
                destination.detectedPeople = detectedPeople
                destination.historicalData = historicalData
            }
        }
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
        
        // Rotate Screen to Portrait
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
