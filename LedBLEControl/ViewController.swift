//
//  ViewController.swift
//  LedBLEControl
//
//  Created by Sergey Gernyak on 2/7/18.
//  Copyright © 2018 Brain Amsterdam. All rights reserved.
//

import Cocoa
import CoreBluetooth

class ViewController: NSViewController {
    fileprivate var centralManager: CBCentralManager?
    @IBOutlet var logsTextView: NSTextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        startCentralManager()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func startCentralManager() {
        let centralQueue = DispatchQueue(label: "com.wearebrain.LedBLEControlQueue", attributes: [])
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
    }
    
    func writeLogEntry(message: String) {
        DispatchQueue.main.async {
            let oldString = self.logsTextView.string
            let newString = oldString + message
            self.logsTextView.string = newString
        }
    }
}

extension ViewController : CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch (central.state) {
        case .poweredOff:
            self.writeLogEntry(message: "BLE discovering is powered off!")
            //            self.clearDevices()
            
        case .unauthorized:
            self.writeLogEntry(message: "BLE discovering is unauthorized!")
            // Indicate to user that the iOS device does not support BLE.
            break
            
        case .unknown:
            self.writeLogEntry(message: "BLE discovering is unknown!")
            // Wait for another event
            break
            
        case .poweredOn:
            self.writeLogEntry(message: "BLE discovering is powered on!")
//            self.canScanning = true
//            self.delegate?.canStartDiscover()
            
        case .resetting:
            self.writeLogEntry(message: "BLE discovering is resetting!")
            //            self.clearDevices()
            
        case .unsupported:
            self.writeLogEntry(message: "BLE discovering is unsupported!")
            break
        }
    }
}
