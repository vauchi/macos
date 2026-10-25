// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Security
@testable import Vauchi
import VauchiPlatform
import XCTest

/// Stands in for the sealed keychain item: the OS check and
/// the keychain status codes are the boundary, everything above it is real.
private final class FakeUserPresenceKeychain: UserPresenceKeychain {
    var canCheckUserPresence = true
    var stored: [UInt8]?
    var replaceCount = 0
    var revealPrompts: [String] = []
    var replaceStatus: OSStatus?
    var revealStatus: OSStatus?
    var revealOverride: [UInt8]?
    var sealedBindings: [UserPresenceBinding] = []

    func replaceSecret(_ secret: [UInt8], binding: UserPresenceBinding) throws {
        if let replaceStatus {
            throw UserPresenceKeychainError.status(replaceStatus)
        }
        replaceCount += 1
        sealedBindings.append(binding)
        stored = secret
    }

    func revealSecret(prompt: String) throws -> [UInt8] {
        revealPrompts.append(prompt)
        if let revealStatus {
            throw UserPresenceKeychainError.status(revealStatus)
        }
        if let revealOverride {
            return revealOverride
        }
        guard let stored else { throw UserPresenceKeychainError.status(errSecItemNotFound) }
        return stored
    }
}

/// Core 0.85.0 asks the shell to seal a secret behind the OS user-presence
/// check (`CreateUserPresenceSecret`) and to unseal it later
/// (`RevealUserPresenceSecret`); the shell answers with the bytes, a
/// cancellation, or `HardwareUnavailable` on the `user_presence` transport
/// (ADR-066, vauchi/private#712).
final class UserPresenceSecretBridgeTests: XCTestCase {
    private let prompt = "Confirm it is you"
    private let firstSecret = (0 ..< 32).map { UInt8($0) }
    private let secondSecret = (0 ..< 32).map { UInt8(200 - $0) }

    /// Core 0.88.0 names the check a create seals under (vauchi/private#778);
    /// `binding: nil` leaves the field out.
    private func command(_ variant: String, binding: String? = "biometry") throws -> PresentationCommand {
        let bindingField = variant == "CreateUserPresenceSecret"
            ? binding.map { #","binding":"\#($0)""# } ?? ""
            : ""
        let json = #"{"commands":[{"\#(variant)":{"prompt":"\#(prompt)"\#(bindingField)}}]}"#
        let commands = try JSONDecoder()
            .decode(PresentationCommandEnvelope.self, from: Data(json.utf8))
            .commands
        return try XCTUnwrap(commands.first)
    }

    private func answer(
        _ variant: String,
        keychain: FakeUserPresenceKeychain,
        random: [UInt8]? = nil
    ) throws -> UserPresenceEvent? {
        let bytes = random ?? firstSecret
        return try UserPresenceSecretBridge.answer(
            to: command(variant),
            keychain: keychain,
            randomBytes: { count in
                XCTAssertEqual(count, 32)
                return bytes
            }
        )
    }

    private func parsed(_ json: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(json.utf8), options: .fragmentsAllowed)
    }

    private var unavailableJSON: String {
        hardwareEventJson(event: .hardwareUnavailable(transport: "user_presence"))
    }

    // MARK: - Create

    func testCreateSealsThirtyTwoRandomBytesAndAnswersWithThemAfterTheCheck() throws {
        let keychain = FakeUserPresenceKeychain()

        let event = try answer("CreateUserPresenceSecret", keychain: keychain)

        XCTAssertEqual(event, .created(firstSecret))
        XCTAssertEqual(keychain.stored, firstSecret)
        XCTAssertEqual(keychain.revealPrompts, [prompt])
        let json = try XCTUnwrap(event?.eventJSON)
        let root = try XCTUnwrap(parsed(json) as? [String: Any])
        XCTAssertEqual(Array(root.keys), ["UserPresenceSecretCreated"])
        let payload = try XCTUnwrap(root["UserPresenceSecretCreated"] as? [String: Any])
        XCTAssertEqual(payload["secret"] as? [Int], firstSecret.map(Int.init))
    }

    /// A biometric seal stops opening when the enrolled fingers or faces
    /// change, so a finger added with only the login password cannot read it
    /// (vauchi/private#778, SAST 415059658).
    func testCreateSealsUnderTheCheckCoreNames() throws {
        for (wire, binding) in [("biometry", UserPresenceBinding.biometry),
                                ("device_credential", .deviceCredential)]
        {
            let keychain = FakeUserPresenceKeychain()

            let event = try UserPresenceSecretBridge.answer(
                to: command("CreateUserPresenceSecret", binding: wire),
                keychain: keychain,
                randomBytes: { _ in self.firstSecret }
            )

            XCTAssertEqual(event, .created(firstSecret), wire)
            XCTAssertEqual(keychain.sealedBindings, [binding], wire)
        }
    }

    /// An unknown or absent binding must not fall back to a weaker seal.
    func testCreateWithAnUnknownOrMissingBindingSealsNothingAndAnswersUnavailable() throws {
        for wire in ["face_or_password", nil] as [String?] {
            let keychain = FakeUserPresenceKeychain()

            let event = try UserPresenceSecretBridge.answer(
                to: command("CreateUserPresenceSecret", binding: wire),
                keychain: keychain,
                randomBytes: { _ in self.firstSecret }
            )

            XCTAssertEqual(event, .unavailable, wire ?? "no binding")
            XCTAssertEqual(keychain.replaceCount, 0, wire ?? "no binding")
            XCTAssertEqual(keychain.revealPrompts, [], wire ?? "no binding")
        }
    }

    func testTheSystemKeychainSealsBiometryToTheCurrentEnrolmentAndTheCredentialToThePassword() {
        XCTAssertEqual(SystemUserPresenceKeychain.accessFlags(for: .biometry), .biometryCurrentSet)
        XCTAssertEqual(SystemUserPresenceKeychain.accessFlags(for: .deviceCredential), .devicePasscode)
    }

    func testASecondCreateReplacesTheSealedSecret() throws {
        let keychain = FakeUserPresenceKeychain()

        _ = try answer("CreateUserPresenceSecret", keychain: keychain, random: firstSecret)
        let event = try answer("CreateUserPresenceSecret", keychain: keychain, random: secondSecret)

        XCTAssertEqual(event, .created(secondSecret))
        XCTAssertEqual(keychain.replaceCount, 2)
        XCTAssertEqual(keychain.stored, secondSecret)
    }

    func testCreateCancelledAtTheCheckAnswersCancelled() throws {
        let keychain = FakeUserPresenceKeychain()
        keychain.revealStatus = errSecUserCanceled

        let event = try answer("CreateUserPresenceSecret", keychain: keychain)

        XCTAssertEqual(event, .cancelled)
        XCTAssertEqual(event?.eventJSON, #""UserPresenceCheckCancelled""#)
    }

    func testCreateWithoutTheKeychainEntitlementAnswersUnavailable() throws {
        let keychain = FakeUserPresenceKeychain()
        keychain.replaceStatus = errSecMissingEntitlement

        let event = try answer("CreateUserPresenceSecret", keychain: keychain)

        XCTAssertEqual(event, .unavailable)
        XCTAssertEqual(keychain.revealPrompts, [])
        XCTAssertEqual(event?.eventJSON, unavailableJSON)
    }

    func testCreateWhenTheRandomSourceFailsAnswersUnavailableAndSealsNothing() throws {
        let keychain = FakeUserPresenceKeychain()

        let event = try UserPresenceSecretBridge.answer(
            to: command("CreateUserPresenceSecret"),
            keychain: keychain,
            randomBytes: { _ in throw UserPresenceKeychainError.status(errSecAllocate) }
        )

        XCTAssertEqual(event, .unavailable)
        XCTAssertNil(keychain.stored)
    }

    func testCreateOnAMacWithoutADeviceCredentialAnswersUnavailableAndSealsNothing() throws {
        let keychain = FakeUserPresenceKeychain()
        keychain.canCheckUserPresence = false

        let event = try answer("CreateUserPresenceSecret", keychain: keychain)

        XCTAssertEqual(event, .unavailable)
        XCTAssertEqual(keychain.replaceCount, 0)
        XCTAssertEqual(keychain.revealPrompts, [])
    }

    // MARK: - Reveal

    func testRevealAnswersWithTheSealedSecretAfterTheCheck() throws {
        let keychain = FakeUserPresenceKeychain()
        keychain.stored = secondSecret

        let event = try answer("RevealUserPresenceSecret", keychain: keychain)

        XCTAssertEqual(event, .revealed(secondSecret))
        XCTAssertEqual(keychain.revealPrompts, [prompt])
        XCTAssertEqual(keychain.replaceCount, 0)
        let json = try XCTUnwrap(event?.eventJSON)
        let root = try XCTUnwrap(parsed(json) as? [String: Any])
        XCTAssertEqual(Array(root.keys), ["UserPresenceSecretRevealed"])
        let payload = try XCTUnwrap(root["UserPresenceSecretRevealed"] as? [String: Any])
        XCTAssertEqual(payload["secret"] as? [Int], secondSecret.map(Int.init))
    }

    func testRevealCancelledAtTheCheckAnswersCancelled() throws {
        let keychain = FakeUserPresenceKeychain()
        keychain.stored = firstSecret
        keychain.revealStatus = errSecUserCanceled

        XCTAssertEqual(try answer("RevealUserPresenceSecret", keychain: keychain), .cancelled)
    }

    /// The OS gave up after repeated wrong attempts: nothing was confirmed,
    /// and Core treats it like a dismissal instead of a fault.
    func testRevealWithFailedAuthenticationAnswersCancelled() throws {
        let keychain = FakeUserPresenceKeychain()
        keychain.stored = firstSecret
        keychain.revealStatus = errSecAuthFailed

        XCTAssertEqual(try answer("RevealUserPresenceSecret", keychain: keychain), .cancelled)
    }

    /// The item is gone, or a biometric seal no longer opens after the
    /// enrolment changed: Core refuses there instead of falling back as it
    /// does for a Mac that cannot run the check (vauchi/private#778).
    func testRevealWithTheItemMissingAnswersMissing() throws {
        let keychain = FakeUserPresenceKeychain()

        let event = try answer("RevealUserPresenceSecret", keychain: keychain)

        XCTAssertEqual(event, .missing)
        XCTAssertEqual(event?.eventJSON, #""UserPresenceSecretMissing""#)
    }

    func testCreateWhoseReadBackFindsNoItemAnswersUnavailable() throws {
        let keychain = FakeUserPresenceKeychain()
        keychain.revealStatus = errSecItemNotFound

        XCTAssertEqual(try answer("CreateUserPresenceSecret", keychain: keychain), .unavailable)
    }

    func testRevealOfAnItemOfTheWrongSizeAnswersUnavailable() throws {
        for size in [0, 31, 33] {
            let keychain = FakeUserPresenceKeychain()
            keychain.revealOverride = [UInt8](repeating: 7, count: size)

            XCTAssertEqual(
                try answer("RevealUserPresenceSecret", keychain: keychain),
                .unavailable,
                "a \(size)-byte item"
            )
        }
    }

    func testCreateWhoseReadBackHasTheWrongSizeAnswersUnavailable() throws {
        let keychain = FakeUserPresenceKeychain()
        keychain.revealOverride = Array(firstSecret.prefix(16))

        XCTAssertEqual(try answer("CreateUserPresenceSecret", keychain: keychain), .unavailable)
    }

    func testRevealWhenTheMacCannotInteractAnswersUnavailable() throws {
        let keychain = FakeUserPresenceKeychain()
        keychain.stored = firstSecret
        keychain.revealStatus = errSecInteractionNotAllowed

        XCTAssertEqual(try answer("RevealUserPresenceSecret", keychain: keychain), .unavailable)
    }

    // MARK: - Other commands

    func testOtherCommandsAreNotAnswered() throws {
        let commands = try JSONDecoder()
            .decode(
                PresentationCommandEnvelope.self,
                from: Data(#"{"commands":["RequestBiometricUnlock"]}"#.utf8)
            )
            .commands
        let keychain = FakeUserPresenceKeychain()

        XCTAssertNil(try UserPresenceSecretBridge.answer(
            to: XCTUnwrap(commands.first),
            keychain: keychain,
            randomBytes: { _ in XCTFail("no secret for another command"); return [] }
        ))
        XCTAssertEqual(keychain.revealPrompts, [])
    }
}
