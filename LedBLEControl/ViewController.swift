//
//  ViewController.swift
//  LedBLEControl
//
//  Created by Sergey Gernyak on 2/7/18.
//  Copyright © 2018 Brain Amsterdam. All rights reserved.
//

import Cocoa
import CoreBluetooth

let targetServiceUUID = CBUUID(string: "FFE0")
let targetCharacteristicUUID = CBUUID(string: "FFE1")

class ViewController: NSViewController {
    fileprivate var centralManager: CBCentralManager?
    @IBOutlet var logsTextView: NSTextView!
    @objc dynamic var canStartConnect: Bool = false
    @objc dynamic var seekingForBoard: Bool = false
    
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
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .medium
            let dateString = dateFormatter.string(from: Date() as Date)
            let oldString = self.logsTextView.string
            let timestampedMessage = "[\(dateString)] \(message)"
            let newString = oldString + timestampedMessage + "\n"
            self.logsTextView.string = newString
        }
    }
    
    @IBAction func onConnectToBoardClicked(_ sender: Any) {
        self.canStartConnect = false
        self.seekingForBoard = true
        centralManager?.scanForPeripherals(withServices: [targetServiceUUID], options: nil)
        self.writeLogEntry(message: "Started to seek for a target board...")
    }
}

extension ViewController : CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch (central.state) {
        case .poweredOff:
            self.writeLogEntry(message: "BLE discovering is powered off!")
            break
        case .unauthorized:
            self.writeLogEntry(message: "BLE discovering is unauthorized!")
            break
        case .unknown:
            self.writeLogEntry(message: "BLE discovering is unknown!")
            break
        case .poweredOn:
            self.writeLogEntry(message: "BLE discovering is powered on!")
            self.canStartConnect = true
            break
        case .resetting:
            self.writeLogEntry(message: "BLE discovering is resetting!")
            break
        case .unsupported:
            self.writeLogEntry(message: "BLE discovering is unsupported!")
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.writeLogEntry(message: "The needed target board has been discovered!")
        self.writeLogEntry(message: "Does an attempt to connect to it...")
        centralManager?.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.writeLogEntry(message: "BLE board has been properly connected!")
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.writeLogEntry(message: "Failed to connect with \(peripheral)! Error is \(String(describing: error))")
    }
}
