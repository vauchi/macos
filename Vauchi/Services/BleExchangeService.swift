// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreBluetooth
import Foundation
import VauchiPlatform

/// CoreBluetooth BLE exchange service for the ADR-031 command/event protocol.
///
/// Executes BLE ExchangeCommands (scan, connect, GATT read/write) using
/// CoreBluetooth and reports results back via a callback. The callback
/// creates MobileExchangeHardwareEvents for the session.
final class BleExchangeService: NSObject {
    /// Callback to report hardware events back to the exchange session.
    typealias EventCallback = (MobileExchangeHardwareEvent) -> Void

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var targetServiceUuid: CBUUID?
    private var connectedPeripheral: CBPeripheral?
    private var discoveredCharacteristics: [String: CBCharacteristic] = [:]
    private var eventCallback: EventCallback?
    private var pendingWrite: (uuid: String, data: Data)?
    private var pendingRead: String?

    // MARK: - Peripheral (Advertising) State

    private var advertisingServiceUuid: CBUUID?
    private var advertisingPayload: Data?
    private var gattCharacteristic: CBMutableCharacteristic?
    private var subscribedCentrals: [CBCentral] = []

    /// Initialize and start CoreBluetooth.
    func activate(callback: @escaping EventCallback) {
        eventCallback = callback
        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: .global(qos: .userInitiated))
        }
    }

    // MARK: - Command Dispatch

    func startScanning(serviceUuid: String) {
        targetServiceUuid = CBUUID(string: serviceUuid)
        guard let manager = centralManager, manager.state == .poweredOn else {
            eventCallback?(.hardwareError(transport: "BLE", error: "Bluetooth not powered on"))
            return
        }
        manager.scanForPeripherals(withServices: [targetServiceUuid!], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false,
        ])
    }

    func startAdvertising(serviceUuid: String, payload: Data = Data()) {
        // macOS supports CBPeripheralManager for BLE advertising.
        // One device advertises while the other scans — the exchange protocol
        // uses this asymmetry to establish the GATT connection.
        advertisingServiceUuid = CBUUID(string: serviceUuid)
        advertisingPayload = payload

        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: .global(qos: .userInitiated))
        } else if peripheralManager?.state == .poweredOn {
            setupGattServiceAndAdvertise()
        }
    }

    func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        if let characteristic = gattCharacteristic,
           let service = characteristic.service
        {
            peripheralManager?.remove(service)
        }
        subscribedCentrals.removeAll()
        gattCharacteristic = nil
        advertisingServiceUuid = nil
        advertisingPayload = nil
    }

    func connect(deviceId: String) {
        guard let peripheral = findPeripheral(id: deviceId) else {
            eventCallback?(.hardwareError(transport: "BLE", error: "Device \(deviceId) not found"))
            return
        }
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager?.connect(peripheral, options: nil)
    }

    func writeCharacteristic(uuid: String, data: Data) {
        guard let peripheral = connectedPeripheral else {
            eventCallback?(.hardwareError(transport: "BLE", error: "No connected device"))
            return
        }
        let normalizedUuid = uuid.lowercased()
        guard let characteristic = discoveredCharacteristics[normalizedUuid] else {
            // Characteristic may not be discovered yet — queue the write
            pendingWrite = (uuid: normalizedUuid, data: Data(data))
            return
        }
        peripheral.writeValue(Data(data), for: characteristic, type: .withResponse)
    }

    func readCharacteristic(uuid: String) {
        guard let peripheral = connectedPeripheral else {
            eventCallback?(.hardwareError(transport: "BLE", error: "No connected device"))
            return
        }
        let normalizedUuid = uuid.lowercased()
        guard let characteristic = discoveredCharacteristics[normalizedUuid] else {
            pendingRead = normalizedUuid
            return
        }
        peripheral.readValue(for: characteristic)
    }

    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
        }
        stopAdvertising()
        cleanup()
    }

    // MARK: - Private

    private var discoveredPeripherals: [String: CBPeripheral] = [:]

    private func findPeripheral(id: String) -> CBPeripheral? {
        discoveredPeripherals[id]
    }

    private func cleanup() {
        connectedPeripheral = nil
        discoveredCharacteristics.removeAll()
        pendingWrite = nil
        pendingRead = nil
        subscribedCentrals.removeAll()
    }

    /// Set up the GATT service with a read/write/notify characteristic and begin advertising.
    private func setupGattServiceAndAdvertise() {
        guard let serviceUuid = advertisingServiceUuid else { return }

        // Create a characteristic that supports read, write, and notify
        let characteristicUuid = CBUUID(string: "00000001-" + serviceUuid.uuidString.dropFirst(8))
        let characteristic = CBMutableCharacteristic(
            type: characteristicUuid,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        gattCharacteristic = characteristic

        // Set initial value from payload
        if let payload = advertisingPayload, !payload.isEmpty {
            characteristic.value = payload
        }

        let service = CBMutableService(type: serviceUuid, primary: true)
        service.characteristics = [characteristic]

        peripheralManager?.add(service)
    }
}

// MARK: - CBCentralManagerDelegate

extension BleExchangeService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Ready — if we have a pending scan, start it
            if let uuid = targetServiceUuid {
                central.scanForPeripherals(withServices: [uuid], options: nil)
            }
        case .poweredOff, .unauthorized, .unsupported:
            eventCallback?(.hardwareUnavailable(transport: "BLE"))
        default:
            break
        }
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let id = peripheral.identifier.uuidString
        discoveredPeripherals[id] = peripheral

        // Extract manufacturer data if available
        let advData: Data = (advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data) ?? Data()

        eventCallback?(.bleDeviceDiscovered(
            id: id,
            rssi: Int16(RSSI.intValue),
            advData: advData
        ))
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        eventCallback?(.bleConnected(deviceId: peripheral.identifier.uuidString))
        // Discover GATT services
        peripheral.discoverServices(nil)
    }

    func centralManager(_: CBCentralManager, didFailToConnect _: CBPeripheral, error: Error?) {
        eventCallback?(.hardwareError(
            transport: "BLE",
            error: error?.localizedDescription ?? "Connection failed"
        ))
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error: Error?) {
        eventCallback?(.bleDisconnected(reason: error?.localizedDescription ?? "disconnected"))
        cleanup()
    }
}

// MARK: - CBPeripheralDelegate

extension BleExchangeService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            eventCallback?(.hardwareError(transport: "BLE", error: "Service discovery failed: \(error!)"))
            return
        }
        // Discover characteristics for all services
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else { return }
        for characteristic in service.characteristics ?? [] {
            let uuid = characteristic.uuid.uuidString.lowercased()
            discoveredCharacteristics[uuid] = characteristic

            // Subscribe to notifications if supported
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }

        // Execute any pending operations now that characteristics are available
        if let pending = pendingWrite, let char = discoveredCharacteristics[pending.uuid] {
            peripheral.writeValue(pending.data, for: char, type: .withResponse)
            pendingWrite = nil
        }
        if let uuid = pendingRead, let char = discoveredCharacteristics[uuid] {
            peripheral.readValue(for: char)
            pendingRead = nil
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil, let value = characteristic.value else { return }
        let uuid = characteristic.uuid.uuidString.lowercased()

        if characteristic.isNotifying {
            eventCallback?(.bleCharacteristicNotified(uuid: uuid, data: value))
        } else {
            eventCallback?(.bleCharacteristicRead(uuid: uuid, data: value))
        }
    }

    func peripheral(_: CBPeripheral, didWriteValueFor _: CBCharacteristic, error: Error?) {
        if let error {
            eventCallback?(.hardwareError(
                transport: "BLE",
                error: "Write failed: \(error.localizedDescription)"
            ))
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BleExchangeService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            // Bluetooth is ready — set up the GATT service and start advertising
            setupGattServiceAndAdvertise()
        case .poweredOff, .unauthorized, .unsupported:
            eventCallback?(.hardwareUnavailable(transport: "BLE-advertise"))
        default:
            break
        }
    }

    func peripheralManager(_: CBPeripheralManager, didAdd _: CBService, error: Error?) {
        guard error == nil else {
            eventCallback?(.hardwareError(
                transport: "BLE-advertise",
                error: "Failed to add GATT service: \(error!.localizedDescription)"
            ))
            return
        }

        // Service registered — start advertising with the service UUID
        guard let serviceUuid = advertisingServiceUuid else { return }
        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [serviceUuid],
            CBAdvertisementDataLocalNameKey: "Vauchi",
        ])
    }

    func peripheralManagerDidStartAdvertising(_: CBPeripheralManager, error: Error?) {
        if let error {
            eventCallback?(.hardwareError(
                transport: "BLE-advertise",
                error: "Advertising failed: \(error.localizedDescription)"
            ))
        }
        // No dedicated "advertising started" event exists in MobileExchangeHardwareEvent.
        // The central's discovery callback (bleDeviceDiscovered) drives the protocol forward.
    }

    func peripheralManager(_: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard let characteristic = gattCharacteristic else {
            peripheralManager?.respond(to: request, withResult: .attributeNotFound)
            return
        }

        guard request.characteristic.uuid == characteristic.uuid else {
            peripheralManager?.respond(to: request, withResult: .attributeNotFound)
            return
        }

        let value = characteristic.value ?? Data()
        guard request.offset <= value.count else {
            peripheralManager?.respond(to: request, withResult: .invalidOffset)
            return
        }

        request.value = value.subdata(in: request.offset ..< value.count)
        peripheralManager?.respond(to: request, withResult: .success)
    }

    func peripheralManager(_: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            guard let characteristic = gattCharacteristic,
                  request.characteristic.uuid == characteristic.uuid
            else {
                peripheralManager?.respond(to: request, withResult: .attributeNotFound)
                return
            }

            guard let data = request.value else {
                peripheralManager?.respond(to: request, withResult: .invalidAttributeValueLength)
                return
            }

            // Update the characteristic value and report to the session
            characteristic.value = data
            peripheralManager?.respond(to: request, withResult: .success)

            let uuid = characteristic.uuid.uuidString.lowercased()
            eventCallback?(.bleCharacteristicNotified(uuid: uuid, data: data))
        }
    }

    func peripheralManager(_: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        guard let gatt = gattCharacteristic, characteristic.uuid == gatt.uuid else { return }
        subscribedCentrals.append(central)
        eventCallback?(.bleConnected(deviceId: central.identifier.uuidString))
    }

    func peripheralManager(_: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard let gatt = gattCharacteristic, characteristic.uuid == gatt.uuid else { return }
        subscribedCentrals.removeAll { $0.identifier == central.identifier }
        eventCallback?(.bleDisconnected(reason: "central unsubscribed"))
    }
}
