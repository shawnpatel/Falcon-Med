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
