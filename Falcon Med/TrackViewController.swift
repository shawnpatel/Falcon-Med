//
//  TrackViewController.swift
//  Falcon Med
//
//  Created by Shawn Patel on 5/27/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import UIKit

class TrackViewController: UIViewController {

    @IBOutlet weak var DJITrack: UIButton!
    @IBOutlet weak var nonDJITrack: UIButton!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        DJITrack.subviews[0].contentMode = .scaleAspectFit
        nonDJITrack.subviews[0].contentMode = .scaleAspectFit
    }
}
