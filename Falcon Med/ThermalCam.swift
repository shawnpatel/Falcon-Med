//
//  ThermalCam.swift
//  Falcon Med
//
//  Created by Shawn Patel on 2/8/19.
//  Copyright © 2019 Shawn Patel. All rights reserved.
//

import CoreBluetooth

class ThermalCam: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    private var centralManager: CBCentralManager!
    private var BLEService_UUID: CBUUID!
    
    override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        BLEService_UUID = CBUUID(string: "6e400001-b5a3-f393-e0a9-e50e24dcca9e")
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            print("Bluetooth Enabled")
            
            startScan()
        } else {
            print("Bluetooth Disabled")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral)
        print(advertisementData)
        print(RSSI)
    }
    
    private func startScan() {
        centralManager?.scanForPeripherals(withServices: [BLEService_UUID] , options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    private func stopScan() {
        centralManager.stopScan()
    }
}
