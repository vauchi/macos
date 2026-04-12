// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// DirectSendService.swift
// TCP client for USB cable exchange (ADR-031).
//
// Connects to the phone's TCP listener, executes the VXCH framing
// protocol, and reports the peer's payload back via callback.

import Foundation

#if canImport(VauchiPlatform)
    import VauchiPlatform

    /// TCP client for USB cable exchange (ADR-031).
    ///
    /// Connects to the phone's TCP listener, executes the VXCH framing
    /// protocol, and reports the peer's payload back via callback.
    final class DirectSendService {
        static let defaultPort: UInt16 = 19283

        typealias EventCallback = (MobileExchangeHardwareEvent) -> Void

        private var eventCallback: EventCallback?

        func setEventCallback(_ callback: @escaping EventCallback) {
            eventCallback = callback
        }

        /// Execute a direct exchange over TCP.
        func exchange(address: String, payload: [UInt8], isInitiator: Bool) {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.performExchange(address: address, payload: payload, isInitiator: isInitiator)
            }
        }

        private func performExchange(address: String, payload: [UInt8], isInitiator: Bool) {
            // Parse address (host:port)
            let parts = address.split(separator: ":")
            let host = parts.count > 0 ? String(parts[0]) : "127.0.0.1"
            let port = parts.count > 1 ? UInt16(parts[1]) ?? Self.defaultPort : Self.defaultPort

            // Connect via BSD sockets (synchronous VXCH framing)
            var hints = addrinfo()
            hints.ai_family = AF_INET
            hints.ai_socktype = SOCK_STREAM

            var result: UnsafeMutablePointer<addrinfo>?
            let status = getaddrinfo(host, String(port), &hints, &result)
            guard status == 0, let addr = result else {
                reportError("DNS resolution failed: \(status)")
                return
            }
            defer { freeaddrinfo(result) }

            let sock = socket(addr.pointee.ai_family, addr.pointee.ai_socktype, addr.pointee.ai_protocol)
            guard sock >= 0 else {
                reportError("socket creation failed")
                return
            }
            defer { close(sock) }

            // Set 10-second send/receive timeouts
            var timeout = timeval(tv_sec: 10, tv_usec: 0)
            setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

            guard Darwin.connect(sock, addr.pointee.ai_addr, addr.pointee.ai_addrlen) == 0 else {
                reportError("TCP connect failed: \(errno)")
                return
            }

            // VXCH framing exchange
            do {
                let theirPayload: [UInt8]
                if isInitiator {
                    try sendVxch(sock: sock, payload: payload)
                    theirPayload = try recvVxch(sock: sock)
                } else {
                    theirPayload = try recvVxch(sock: sock)
                    try sendVxch(sock: sock, payload: payload)
                }

                DispatchQueue.main.async { [weak self] in
                    self?.eventCallback?(.directPayloadReceived(data: Data(theirPayload)))
                }
            } catch {
                reportError("exchange failed: \(error.localizedDescription)")
            }
        }

        // VXCH wire format: [4 bytes magic "VXCH"] [1 byte version] [4 bytes BE length] [payload]
        private static let magic: [UInt8] = [0x56, 0x58, 0x43, 0x48] // "VXCH"
        private static let version: UInt8 = 1
        private static let maxPayload: UInt32 = 65_536

        private func sendVxch(sock: Int32, payload: [UInt8]) throws {
            guard !payload.isEmpty else { throw VxchError.emptyPayload }
            var header = Self.magic
            header.append(Self.version)
            let len = UInt32(payload.count).bigEndian
            withUnsafeBytes(of: len) { header.append(contentsOf: $0) }

            try sendAll(sock: sock, data: header)
            try sendAll(sock: sock, data: payload)
        }

        private func recvVxch(sock: Int32) throws -> [UInt8] {
            // Read header (9 bytes: 4 magic + 1 version + 4 length)
            let header = try recvExact(sock: sock, count: 9)
            guard Array(header[0 ..< 4]) == Self.magic else {
                throw VxchError.invalidMagic
            }
            guard header[4] == Self.version else {
                throw VxchError.unsupportedVersion
            }
            let len = UInt32(bigEndian: header[5 ..< 9].withUnsafeBytes { $0.load(as: UInt32.self) })
            guard len > 0, len <= Self.maxPayload else {
                throw VxchError.invalidLength(len)
            }
            return try recvExact(sock: sock, count: Int(len))
        }

        private func sendAll(sock: Int32, data: [UInt8]) throws {
            var sent = 0
            while sent < data.count {
                let n = data[sent...].withUnsafeBytes {
                    Darwin.send(sock, $0.baseAddress!, data.count - sent, 0)
                }
                guard n > 0 else { throw VxchError.sendFailed }
                sent += n
            }
        }

        private func recvExact(sock: Int32, count: Int) throws -> [UInt8] {
            var buf = [UInt8](repeating: 0, count: count)
            var received = 0
            while received < count {
                let n = buf[received...].withUnsafeMutableBytes {
                    Darwin.recv(sock, $0.baseAddress!, count - received, 0)
                }
                guard n > 0 else { throw VxchError.recvFailed }
                received += n
            }
            return buf
        }

        private func reportError(_ message: String) {
            DispatchQueue.main.async { [weak self] in
                self?.eventCallback?(.hardwareError(transport: "USB", error: message))
            }
        }

        private enum VxchError: Error {
            case emptyPayload, invalidMagic, unsupportedVersion
            case invalidLength(UInt32), sendFailed, recvFailed
        }
    }
#endif
