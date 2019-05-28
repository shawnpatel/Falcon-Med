//
//  NetworkCalls.swift
//  Falcon Med
//
//  Created by Shawn Patel on 5/19/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import Foundation

import Firebase

class NetworkCalls {
    
    static let databaseRef = Database.database().reference()
    static let storage = Storage.storage()
    
    static let uid = Auth.auth().currentUser?.uid
    
    static func downloadLiveData(completion: @escaping (Result<LiveData, NetworkError>) -> Void) {
        databaseRef.child("flights/\(uid!)/live").observeSingleEvent(of: .value, with: { (snapshot) in
            if let data = snapshot.value as? NSDictionary {
                let takeoffTime = data["takeoffTime"] as? Int ?? 0
                
                let latitude = data["latitude"] as? Double ?? 0
                let longitude = data["longitude"] as? Double ?? 0
                
                let altitude = data["altitude"] as? Double ?? 0
                let heading = data["heading"] as? Double ?? 0
                
                let speed = data["speed"] as? Double ?? 0
                
                let accelX = data["accelX"] as? Double ?? 0
                let accelY = data["accelY"] as? Double ?? 0
                let accelZ = data["accelZ"] as? Double ?? 0
                
                let liveData = LiveData(takeoffTime, latitude, longitude, altitude, heading, speed, accelX, accelY, accelZ)
                
                completion(.success(liveData))
            } else {
                completion(.failure(.notLive))
            }
        }) { (error) in
            completion(.failure(.firebaseDatabaseError(error.localizedDescription)))
        }
    }
    
    static func refreshLiveData(completion: @escaping (Result<LiveData, NetworkError>) -> Void) {
        
    }
    
    static func downloadImage(_ url: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        let httpsRef = storage.reference(forURL: url)
        
        httpsRef.getData(maxSize: Int64.max) { data, error in
            if let error = error {
                completion(.failure(error))
            } else {
                let image = UIImage(data: data!)
                
                completion(.success(image!))
            }
        }
    }
}
