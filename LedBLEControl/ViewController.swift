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
let peripheralDefaultName = "Unnamed device"

class ViewController: NSViewController {
    fileprivate var centralManager: CBCentralManager?
    fileprivate var targetCharacteristic: CBCharacteristic?
    fileprivate var targetPeripheral: CBPeripheral?
    @IBOutlet var logsTextView: NSTextView!
    @IBOutlet weak var customBytesTextField: NSTextFieldCell!
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
        let centralQueue = DispatchQueue(label: "com.sergiogernyak.LedBLEControlQueue", attributes: [])
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
    
    func normalizePeripheralName(_ name: String?) -> String {
        if (name != nil) { return name! }
        return peripheralDefaultName
    }
    
    @IBAction func onConnectToBoardClicked(_ sender: Any) {
        self.canStartConnect = false
        self.seekingForBoard = true
        centralManager?.scanForPeripherals(withServices: [targetServiceUUID], options: nil)
        self.writeLogEntry(message: "Started to seek for a target board...")
    }
    
    @IBAction func onLEDOnClicked(_ sender: Any) {
        self.writeLogEntry(message: "LED on command is sent!")
        self.targetPeripheral?.writeValue(Data.init([1]), for: self.targetCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
    }
    
    @IBAction func onLEDOffClicked(_ sender: Any) {
        self.writeLogEntry(message: "LED off command is sent!")
        self.targetPeripheral?.writeValue(Data.init([0]), for: self.targetCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
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
    
    @IBAction func onSendBytesClicked(_ sender: Any) {
        self.writeLogEntry(message: "[26, 4, 127, 240, 100, 8] bytes sequence is sent!")
        self.targetPeripheral?.writeValue(Data.init([26, 4, 127, 240, 100, 8]), for: self.targetCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
    }
    
    @IBAction func onSendCustomBytesClick(_ sender: Any) {
        let customBytesString = self.customBytesTextField.stringValue
        self.writeLogEntry(message: "onSendCustomBytesClick is called! The custom bytes are \(customBytesString)")
        let messageBytes = customBytesString
            .split(separator: " ")
            .map({ (byteString) -> UInt8 in
                let result = UInt8(byteString, radix: 16)
                if result != nil {
                    return result!
                } else {
                    return 0
                }
            })
        self.targetPeripheral?.writeValue(Data.init(messageBytes), for: self.targetCharacteristic!, type: CBCharacteristicWriteType.withoutResponse)
    }
}

extension ViewController : CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch (central.state) {
        case .poweredOff:
            self.writeLogEntry(message: "BLE discovering is powered off!")
            DispatchQueue.main.async {
                self.canStartConnect = false
                self.seekingForBoard = false
                self.centralManager?.stopScan()
            }
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
        @unknown default:
            self.writeLogEntry(message: "Doesn't know how to tackle with the BLE state \(central.state)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.writeLogEntry(message: "The needed target board has been discovered with a name `\(normalizePeripheralName(peripheral.name))`!")
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
        self.writeLogEntry(message: "Peripheral `\(normalizePeripheralName(peripheral.name))` has been disconnected! Possible reason is \(String(describing: error))")
        DispatchQueue.main.async {
            self.canStartConnect = true
            self.seekingForBoard = false
            self.canControlLED = false
        }
    }
}

extension ViewController : CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        self.writeLogEntry(message: "The services for `\(normalizePeripheralName(peripheral.name))` have been discovered!")
        for service in peripheral.services! {
            if (service.uuid == targetServiceUUID) {
                self.writeLogEntry(message: "The target service has been found in the discovered list!")
                self.writeLogEntry(message: "Doing an attempt to discover service's characteristics...")
                peripheral.discoverCharacteristics([targetCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        self.writeLogEntry(message: "The characteristics for `\(normalizePeripheralName(peripheral.name))` have been discovered!")
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
