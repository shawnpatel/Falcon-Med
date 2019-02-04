//
//  ImageAnalysis.swift
//  Falcon Med
//
//  Created by Shawn Patel on 1/7/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import UIKit
import CoreML
import Vision

class ImageAnalysis {
    
    private let model: MLModel!
    private let image: UIImage!
    
    init(model: MLModel, image: UIImage) {
        self.model = model
        self.image = image
    }
    
    func detect(completion: @escaping (Error?, String?) -> ()) {
        guard let model = try? VNCoreMLModel(for: model) else {
            fatalError("Can't load model.")
        }
        
        let request = VNCoreMLRequest(model: model) { request, error in
            guard let results = request.results as? [VNClassificationObservation], let topResult = results.first else {
                fatalError("Unexpected result type from VNCoreMLRequest.")
            }
            
            let scenes = topResult.identifier.components(separatedBy: ", ")
            let scene = scenes[0].replacingOccurrences(of: "_", with: " ").capitalized
            
            completion(nil, scene)
        }
        
        let handler = VNImageRequestHandler(ciImage: CIImage(image: image)!)
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([request])
            } catch {
                completion(error, nil)
            }
        }
    }
}
