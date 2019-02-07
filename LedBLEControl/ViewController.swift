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
    fileprivate var targetCharacteristic: CBCharacteristic?
    fileprivate var targetPeripheral: CBPeripheral?
    @IBOutlet var logsTextView: NSTextView!
    @objc dynamic var canStartConnect: Bool = false
    @objc dynamic var seekingForBoard: Bool = false
    @objc dynamic var canControlLED: Bool = false
    
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
    
    @IBAction func onLEDOnClicked(_ sender: Any) {
        self.writeLogEntry(message: "LED on command is sent!")
        self.targetPeripheral?.writeValue(Data.init(bytes: [1]), for: self.targetCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
    }
    
    @IBAction func onLEDOffClicked(_ sender: Any) {
        self.writeLogEntry(message: "LED off command is sent!")
        self.targetPeripheral?.writeValue(Data.init(bytes: [0]), for: self.targetCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
    }
    
    @IBAction func onStopConnectClicked(_ sender: Any) {
        self.centralManager?.stopScan()
        self.canStartConnect = true
        self.seekingForBoard = false
        self.writeLogEntry(message: "Seeking for the target board has been stopped!")
    }
    
    @IBAction func onDisconnectFromBoardClicked(_ sender: Any) {
        self.centralManager?.cancelPeripheralConnection(self.targetPeripheral!)
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
            DispatchQueue.main.async {
                self.canStartConnect = true
            }
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
        self.writeLogEntry(message: "The needed target board has been discovered with a name `\(peripheral.name!)`!")
        self.writeLogEntry(message: "Doing an attempt to connect to it...")
        self.targetPeripheral = peripheral
        self.targetPeripheral!.delegate = self
        centralManager?.stopScan()
        centralManager?.connect(self.targetPeripheral!, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.writeLogEntry(message: "BLE board has been properly connected!")
        self.writeLogEntry(message: "Doing an attempt to discover peripheral's services...")
        peripheral.delegate = self
        peripheral.discoverServices([targetServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.writeLogEntry(message: "Failed to connect with \(peripheral)! Error is \(String(describing: error))")
        DispatchQueue.main.async {
            self.canStartConnect = true
            self.seekingForBoard = false
            self.canControlLED = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.writeLogEntry(message: "Peripheral `\(peripheral.name!)` has been disconnected! Possible reason is \(String(describing: error))")
        DispatchQueue.main.async {
            self.canStartConnect = true
            self.seekingForBoard = false
            self.canControlLED = false
        }
    }
}

extension ViewController : CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        self.writeLogEntry(message: "The services for `\(peripheral.name!)` have been discovered!")
        for service in peripheral.services! {
            if (service.uuid == targetServiceUUID) {
                self.writeLogEntry(message: "The target service has been found in the discovered list!")
                self.writeLogEntry(message: "Doing an attempt to discover service's characteristics...")
                peripheral.discoverCharacteristics([targetCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        self.writeLogEntry(message: "The characteristics for `\(peripheral.name!)` have been discovered!")
        for characteristic in service.characteristics! {
            if (characteristic.uuid == targetCharacteristicUUID) {
                self.writeLogEntry(message: "The target characteristic has been found in the discovered list!")
                self.writeLogEntry(message: "The preparation process has been completed! You are ready to control the board!")
                self.targetCharacteristic = characteristic
            }
        }
        DispatchQueue.main.async {
            self.seekingForBoard = false
            self.canControlLED = true
        }
    }
}
