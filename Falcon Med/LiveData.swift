//
//  LiveData.swift
//  Falcon Med
//
//  Created by Shawn Patel on 5/19/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import Foundation

class LiveData {
    
    // Declare Variables
    private var _takeoffTime: Int!
    
    private var _latitude: Double!
    private var _longitude: Double!
    
    private var _altitude: Double!
    private var _heading: Double!
    
    private var _speed: Double!
    private var _accelX: Double!
    private var _accelY: Double!
    private var _accelZ: Double!
    
    // Initialize Class
    init(_ takeoffTime: Int, _ latitude: Double, _ longitude: Double, _ altitude: Double, _ heading: Double, _ speed: Double, _ accelX: Double, _ accelY: Double, _ accelZ: Double) {
        self._takeoffTime = takeoffTime
        
        self._latitude = latitude
        self._longitude = longitude
        
        self._altitude = altitude
        self._heading = heading
        
        self._speed = speed
        self._accelX = accelX
        self._accelY = accelY
        self._accelZ = accelZ
    }
    
    // Getters and Setters
    public var takeoffTime: Int {
        get { return _takeoffTime }
        set { _takeoffTime = newValue }
    }
    
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
    
    public var heading: Double {
        get { return _heading }
        set { _heading = newValue }
    }
    
    public var speed: Double {
        get { return _speed }
        set { _speed = newValue }
    }
    
    public var accelX: Double {
        get { return _accelX }
        set { _accelX = newValue }
    }
    
    public var accelY: Double {
        get { return _accelY }
        set { _accelY = newValue }
    }
    
    public var accelZ: Double {
        get { return _accelZ }
        set { _accelZ = newValue }
    }
}
