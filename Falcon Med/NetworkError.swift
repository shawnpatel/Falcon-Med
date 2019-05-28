//
//  NetworkError.swift
//  Falcon Med
//
//  Created by Shawn Patel on 5/19/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import Foundation

enum NetworkError: Error, Equatable {
    case notLive
    case firebaseDatabaseError(String)
}

extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notLive:
            return NSLocalizedString("101", comment: "Drone is not live.")
        
        case .firebaseDatabaseError(let error):
            return NSLocalizedString(error, comment: "")
        }
    }
}
