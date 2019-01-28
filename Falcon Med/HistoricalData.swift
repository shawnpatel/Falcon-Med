//
//  HistoricalData.swift
//  Falcon Med
//
//  Created by Shawn Patel on 1/28/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

class HistoricalData {
    
    // Declare Variables
    private var _timestamp: Int!
    private var _latitude: Double!
    private var _longitude: Double!
    private var _altitude: Double!
    private var _heading: Double!
    
    // Initialize Class
    init(_ timestamp: Int, _ latitude: Double, _ longitude: Double, _ altitude: Double, _ heading: Double) {
        self._timestamp = timestamp
        self._latitude = latitude
        self._longitude = longitude
        self._altitude = altitude
        self._heading = heading
    }
    
    // Getters and Setters
    public var timestamp: Int {
        get { return _timestamp }
        set { _timestamp = newValue }
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
}
