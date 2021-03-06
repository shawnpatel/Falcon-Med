//
//  DetectedPerson.swift
//  Falcon Med
//
//  Created by Shawn Patel on 1/11/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import UIKit
import Foundation

class DetectedPerson {

    // Declare Variables
    private var _latitude: Double!
    private var _longitude: Double!
    private var _altitude: Double!
    
    private var _leftEyeOpenProbability: Int!
    private var _rightEyeOpenProbability: Int!
    
    private var _gender: String!
    private var _age: String!
    private var _scene: String!
    
    private var _image: UIImage!
    
    // Initialize Class
    init(_ latitude: Double, _ longitude: Double, _ altitude: Double, _ leftEyeOpenProbability: Int, _ rightEyeOpenProbability: Int) {
        self._latitude = latitude
        self._longitude = longitude
        self._altitude = altitude
        
        self._leftEyeOpenProbability = leftEyeOpenProbability
        self._rightEyeOpenProbability = rightEyeOpenProbability
        
    }
    
    init(_ latitude: Double, _ longitude: Double, _ altitude: Double, _ leftEyeOpenProbability: Int, _ rightEyeOpenProbability: Int, _ gender: String, _ age: String, _ scene: String) {
        self._latitude = latitude
        self._longitude = longitude
        self._altitude = altitude
        
        self._leftEyeOpenProbability = leftEyeOpenProbability
        self._rightEyeOpenProbability = rightEyeOpenProbability
        
        self._gender = gender
        self._age = age
        self._scene = scene
    }
    
    // Getters and Setters
    public var latitude: Double {
        get { return _latitude }
        set { _latitude = newValue }
    }
    
    public var longitude: Double {
        get { return _longitude }
        set { _longitude = newValue }
    }
    
    public var altitude: Double {
        get { return _altitude }
        set { _altitude = newValue }
    }
    
    public var leftEyeOpenProbability: Int {
        get { return _leftEyeOpenProbability }
        set { _leftEyeOpenProbability = newValue }
    }
    
    public var rightEyeOpenProbability: Int {
        get { return _rightEyeOpenProbability }
        set { _rightEyeOpenProbability = newValue }
    }
    
    public var gender: String {
        get { return _gender }
        set { _gender = newValue }
    }
    
    public var age: String {
        get { return _age }
        set { _age = newValue }
    }
    
    public var scene: String {
        get { return _scene }
        set { _scene = newValue }
    }
    
    public var image: UIImage {
        get { return _image }
        set { _image = newValue }
    }
}
