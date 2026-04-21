// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

// Models.swift
// Decodable types matching core UI JSON output (serde snake_case)
// Maps to: vauchi-core/src/ui/screen.rs, component.rs, action.rs
//
// Shared with iOS — this file is identical to ios/Vauchi/CoreUI/Models.swift.
// TODO: Extract to vauchi-platform-swift SPM package to avoid duplication.

import Foundation
import SwiftUI

// MARK: - Design Token Environment

private struct DesignTokensKey: EnvironmentKey {
    static let defaultValue: DesignTokens = .defaults
}

extension EnvironmentValues {
    var designTokens: DesignTokens {
        get { self[DesignTokensKey.self] }
        set { self[DesignTokensKey.self] = newValue }
    }
}

// MARK: - JSON Decoding Strategy

/// Shared decoder configured for serde snake_case output.
let coreJSONDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
}()

/// Shared encoder for sending UserAction to core.
/// Does NOT use `.convertToSnakeCase` because UserAction's custom `encode(to:)`
/// already emits the correct keys (PascalCase variant names like "TextChanged",
/// snake_case field names like "component_id"). Applying `.convertToSnakeCase`
/// would corrupt variant keys to "text_changed", breaking serde deserialization.
let coreJSONEncoder: JSONEncoder = .init()

// MARK: - Design Tokens

/// Layout tokens for consistent cross-platform rendering.
/// Maps to: `vauchi-core::theme::DesignTokens`
struct DesignTokens: Decodable {
    let spacing: SpacingTokens
    let spacingDirection: SpacingDirectionTokens
    let typography: TypographyTokens
    let borderRadius: BorderRadiusTokens
    let touchTarget: TouchTargetTokens
    let motion: MotionTokens

    static let defaults = DesignTokens(
        spacing: SpacingTokens(
            xs: 4, sm: 8, md: 16, lg: 24, xl: 32
        ),
        spacingDirection: SpacingDirectionTokens(
            contentStart: 16, contentEnd: 16,
            listItemStart: 8, listItemEnd: 8,
            listItemInlineStart: 12, listItemInlineEnd: 12
        ),
        typography: TypographyTokens(
            titleSize: 24, subtitleSize: 18,
            bodySize: 16, captionSize: 14
        ),
        borderRadius: BorderRadiusTokens(
            sm: 4, md: 8, mdLg: 12, lg: 16
        ),
        touchTarget: TouchTargetTokens(minimum: 44),
        motion: MotionTokens(
            enterDurationMs: 200, exitDurationMs: 150,
            emphasisDurationMs: 300
        )
    )
}

// swiftlint:disable identifier_name
struct SpacingTokens: Decodable {
    let xs: UInt16
    let sm: UInt16
    let md: UInt16
    let lg: UInt16
    let xl: UInt16
}

// swiftlint:enable identifier_name

struct SpacingDirectionTokens: Decodable {
    let contentStart: UInt16
    let contentEnd: UInt16
    let listItemStart: UInt16
    let listItemEnd: UInt16
    let listItemInlineStart: UInt16
    let listItemInlineEnd: UInt16
}

struct TypographyTokens: Decodable {
    let titleSize: UInt16
    let subtitleSize: UInt16
    let bodySize: UInt16
    let captionSize: UInt16
}

// swiftlint:disable identifier_name
struct BorderRadiusTokens: Decodable {
    let sm: UInt16
    let md: UInt16
    let mdLg: UInt16
    let lg: UInt16
}

// swiftlint:enable identifier_name

struct TouchTargetTokens: Decodable {
    let minimum: UInt16
}

struct MotionTokens: Decodable {
    let enterDurationMs: UInt16
    let exitDurationMs: UInt16
    let emphasisDurationMs: UInt16
}

// MARK: - ScreenModel

/// Describes a full screen to render.
/// Maps to: `vauchi-core::ui::screen::ScreenModel`
struct ScreenModel: Decodable {
    let screenId: String
    let title: String
    let subtitle: String?
    let components: [Component]
    let actions: [ScreenAction]
    let progress: Progress?
    let tokens: DesignTokens

    private enum CodingKeys: String, CodingKey {
        case screenId, title, subtitle, components, actions, progress, tokens
    }

    init(
        screenId: String,
        title: String,
        subtitle: String? = nil,
        components: [Component] = [],
        actions: [ScreenAction] = [],
        progress: Progress? = nil,
        tokens: DesignTokens = .defaults
    ) {
        self.screenId = screenId
        self.title = title
        self.subtitle = subtitle
        self.components = components
        self.actions = actions
        self.progress = progress
        self.tokens = tokens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        screenId = try container.decode(String.self, forKey: .screenId)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decodeIfPresent(String.self, forKey: .subtitle)
        components = try container.decode([Component].self, forKey: .components)
        actions = try container.decode([ScreenAction].self, forKey: .actions)
        progress = try container.decodeIfPresent(Progress.self, forKey: .progress)
        tokens = try container.decodeIfPresent(DesignTokens.self, forKey: .tokens) ?? .defaults
    }
}

/// Step progress indicator.
/// Maps to: `vauchi-core::ui::screen::Progress`
struct Progress: Decodable {
    let currentStep: UInt8
    let totalSteps: UInt8
    let label: String?
}

/// A button or action the user can take on the screen.
/// Maps to: `vauchi-core::ui::screen::ScreenAction`
struct ScreenAction: Decodable, Identifiable {
    let id: String
    let label: String
    let style: ActionStyle
    let enabled: Bool
    /// Optional accessibility override. When `nil`, SwiftUI falls
    /// back to deriving the screen-reader announcement from
    /// `label`. When `Some`, `a11y.label` replaces it and
    /// `a11y.hint` surfaces as the VoiceOver hint.
    /// See `_private/docs/problems/2026-04-20-screen-action-a11y-identifier-gap`.
    let a11y: A11y?

    /// Explicit memberwise init. A plain `let a11y: A11y? = nil`
    /// default would satisfy existing test literals but blocks
    /// `Decodable` synthesis from overwriting the field with the
    /// JSON value. The explicit init keeps both paths working:
    /// - struct-literal callers omit `a11y:` (defaults to `nil`),
    /// - JSON decoding uses the synthesized `init(from:)` which
    ///   calls `decodeIfPresent` for the `A11y?` field.
    init(id: String, label: String, style: ActionStyle, enabled: Bool, a11y: A11y? = nil) {
        self.id = id
        self.label = label
        self.style = style
        self.enabled = enabled
        self.a11y = a11y
    }
}

/// Visual style for a screen action.
/// Maps to: `vauchi-core::ui::screen::ActionStyle`
enum ActionStyle: String, Decodable {
    case primary = "Primary"
    case secondary = "Secondary"
    case destructive = "Destructive"
}

// MARK: - Component

/// A UI component that core tells frontends to render.
/// Maps to: `vauchi-core::ui::component::Component`
///
/// Rust serde serializes enums as `{"VariantName": {"field": "value"}}` or
/// `"VariantName"` for unit variants. We use custom `Decodable` to handle this.
enum Component: Decodable {
    case text(TextComponent)
    case textInput(TextInputComponent)
    case toggleList(ToggleListComponent)
    case fieldList(FieldListComponent)
    case cardPreview(CardPreviewComponent)
    case infoPanel(InfoPanelComponent)
    case contactList(ContactListComponent)
    case settingsGroup(SettingsGroupComponent)
    case actionList(ActionListComponent)
    case statusIndicator(StatusIndicatorComponent)
    case pinInput(PinInputComponent)
    case qrCode(QrCodeComponent)
    case confirmationDialog(ConfirmationDialogComponent)
    case showToast(ShowToastComponent)
    case inlineConfirm(InlineConfirmComponent)
    case editableText(EditableTextComponent)
    case banner(BannerComponent)
    case avatarPreview(AvatarPreviewComponent)
    case slider(SliderComponent)
    case divider
    case unknown

    init(from decoder: Decoder) throws {
        // Try unit variant first ("Divider")
        if let container = try? decoder.singleValueContainer(),
           let stringValue = try? container.decode(String.self),
           stringValue == "Divider"
        {
            self = .divider
            return
        }

        // Struct variants: {"VariantName": {...}}
        let container = try decoder.container(keyedBy: VariantKey.self)
        self = try Self.decodeStructVariant(from: container, codingPath: decoder.codingPath)
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func decodeStructVariant(
        from container: KeyedDecodingContainer<VariantKey>,
        codingPath _: [CodingKey]
    ) throws -> Component {
        if container.contains(.text) {
            return try .text(container.decode(TextComponent.self, forKey: .text))
        } else if container.contains(.textInput) {
            return try .textInput(container.decode(TextInputComponent.self, forKey: .textInput))
        } else if container.contains(.toggleList) {
            return try .toggleList(container.decode(ToggleListComponent.self, forKey: .toggleList))
        } else if container.contains(.fieldList) {
            return try .fieldList(container.decode(FieldListComponent.self, forKey: .fieldList))
        } else if container.contains(.cardPreview) {
            return try .cardPreview(container.decode(CardPreviewComponent.self, forKey: .cardPreview))
        } else if container.contains(.infoPanel) {
            return try .infoPanel(container.decode(InfoPanelComponent.self, forKey: .infoPanel))
        } else if container.contains(.contactList) {
            return try .contactList(container.decode(ContactListComponent.self, forKey: .contactList))
        } else if container.contains(.settingsGroup) {
            return try .settingsGroup(container.decode(SettingsGroupComponent.self, forKey: .settingsGroup))
        } else if container.contains(.actionList) {
            return try .actionList(container.decode(ActionListComponent.self, forKey: .actionList))
        } else if container.contains(.statusIndicator) {
            return try .statusIndicator(container.decode(StatusIndicatorComponent.self, forKey: .statusIndicator))
        } else if container.contains(.pinInput) {
            return try .pinInput(container.decode(PinInputComponent.self, forKey: .pinInput))
        } else if container.contains(.qrCode) {
            return try .qrCode(container.decode(QrCodeComponent.self, forKey: .qrCode))
        } else if container.contains(.confirmationDialog) {
            return try .confirmationDialog(
                container.decode(ConfirmationDialogComponent.self, forKey: .confirmationDialog)
            )
        } else if container.contains(.showToast) {
            return try .showToast(container.decode(ShowToastComponent.self, forKey: .showToast))
        } else if container.contains(.inlineConfirm) {
            return try .inlineConfirm(
                container.decode(InlineConfirmComponent.self, forKey: .inlineConfirm)
            )
        } else if container.contains(.editableText) {
            return try .editableText(
                container.decode(EditableTextComponent.self, forKey: .editableText)
            )
        } else if container.contains(.banner) {
            return try .banner(container.decode(BannerComponent.self, forKey: .banner))
        } else if container.contains(.avatarPreview) {
            return try .avatarPreview(
                container.decode(AvatarPreviewComponent.self, forKey: .avatarPreview)
            )
        } else if container.contains(.slider) {
            return try .slider(container.decode(SliderComponent.self, forKey: .slider))
        }
        return .unknown
    }

    private enum VariantKey: String, CodingKey {
        case text = "Text"
        case textInput = "TextInput"
        case toggleList = "ToggleList"
        case fieldList = "FieldList"
        case cardPreview = "CardPreview"
        case infoPanel = "InfoPanel"
        case contactList = "ContactList"
        case settingsGroup = "SettingsGroup"
        case actionList = "ActionList"
        case statusIndicator = "StatusIndicator"
        case pinInput = "PinInput"
        case qrCode = "QrCode"
        case confirmationDialog = "ConfirmationDialog"
        case showToast = "ShowToast"
        case inlineConfirm = "InlineConfirm"
        case editableText = "EditableText"
        case banner = "Banner"
        case avatarPreview = "AvatarPreview"
        case slider = "Slider"
    }
}

// MARK: - A11y

/// Core-driven accessibility metadata attached to components.
/// Maps to: `vauchi-core::ui::component::A11y`
struct A11y: Decodable {
    let label: String?
    let hint: String?
    let role: String?
}

// MARK: - Component Data Types

struct TextComponent: Decodable {
    let id: String
    let content: String
    let style: TextStyle
}

enum TextStyle: String, Decodable {
    case title = "Title"
    case subtitle = "Subtitle"
    case body = "Body"
    case caption = "Caption"
}

struct TextInputComponent: Decodable {
    let id: String
    let label: String
    let value: String
    let placeholder: String?
    let maxLength: Int?
    let validationError: String?
    let inputType: InputType
    var a11y: A11y?
}

enum InputType: String, Decodable {
    case text = "Text"
    case phone = "Phone"
    case email = "Email"
    case password = "Password"
}

struct ToggleListComponent: Decodable {
    let id: String
    let label: String
    let items: [ToggleItem]
    var a11y: A11y?
}

struct ToggleItem: Decodable, Identifiable {
    let id: String
    let label: String
    let selected: Bool
    let subtitle: String?
    var a11y: A11y?
}

struct FieldListComponent: Decodable {
    let id: String
    let fields: [FieldDisplay]
    let visibilityMode: VisibilityMode
    let availableGroups: [String]
    var a11y: A11y?
}

enum VisibilityMode: String, Decodable {
    case showHide = "ShowHide"
    case perGroup = "PerGroup"
}

struct FieldDisplay: Decodable, Identifiable {
    let id: String
    let fieldType: String
    let label: String
    let value: String
    let visibility: UiFieldVisibility
    var a11y: A11y?
}

/// UI-level field visibility state.
/// Serde outputs: `"Shown"`, `"Hidden"`, or `{"Groups": ["Family", ...]}`
enum UiFieldVisibility: Decodable {
    case shown
    case hidden
    case groups([String])

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let stringValue = try? container.decode(String.self)
        {
            switch stringValue {
            case "Shown": self = .shown
            case "Hidden": self = .hidden
            // Unknown visibility — default to shown
            default: self = .shown
            }
            return
        }

        let container = try decoder.container(keyedBy: GroupsKey.self)
        let groups = try container.decode([String].self, forKey: .groups)
        self = .groups(groups)
    }

    private enum GroupsKey: String, CodingKey {
        case groups = "Groups"
    }
}

struct CardPreviewComponent: Decodable {
    let name: String
    let avatarData: [UInt8]?
    let fields: [FieldDisplay]
    let groupViews: [GroupCardView]
    let selectedGroup: String?
    var a11y: A11y?
}

struct GroupCardView: Decodable, Identifiable {
    let groupName: String
    let displayName: String
    let visibleFields: [FieldDisplay]

    var id: String {
        groupName
    }
}

struct InfoPanelComponent: Decodable {
    let id: String
    let icon: String?
    let title: String
    let items: [InfoItem]
    var a11y: A11y?
}

struct InfoItem: Decodable, Identifiable {
    let icon: String?
    let title: String
    let detail: String

    var id: String {
        title
    }
}

// MARK: - ContactList Component

struct ContactListComponent: Decodable {
    let id: String
    let contacts: [ContactItem]
    let searchable: Bool
}

struct ContactItem: Decodable, Identifiable {
    let id: String
    let name: String
    let subtitle: String?
    let avatarInitials: String
    let status: String?
    var a11y: A11y?
}

// MARK: - SettingsGroup Component

struct SettingsGroupComponent: Decodable {
    let id: String
    let label: String
    let items: [SettingsItem]
}

struct SettingsItem: Decodable, Identifiable {
    let id: String
    let label: String
    let kind: SettingsItemKind
    var a11y: A11y?
}

enum SettingsItemKind: Decodable {
    case toggle(enabled: Bool)
    case value(value: String)
    case link(detail: String?)
    case destructive(label: String)
    case unknown

    init(from decoder: Decoder) throws {
        // Serde produces: {"Toggle": {"enabled": true}}, etc.
        let container = try decoder.container(keyedBy: VariantKey.self)
        if container.contains(.toggle) {
            let data = try container.decode(ToggleData.self, forKey: .toggle)
            self = .toggle(enabled: data.enabled)
        } else if container.contains(.value) {
            let data = try container.decode(ValueData.self, forKey: .value)
            self = .value(value: data.value)
        } else if container.contains(.link) {
            let data = try container.decode(LinkData.self, forKey: .link)
            self = .link(detail: data.detail)
        } else if container.contains(.destructive) {
            let data = try container.decode(DestructiveData.self, forKey: .destructive)
            self = .destructive(label: data.label)
        } else {
            self = .unknown
        }
    }

    private enum VariantKey: String, CodingKey {
        case toggle = "Toggle"
        case value = "Value"
        case link = "Link"
        case destructive = "Destructive"
    }

    private struct ToggleData: Decodable { let enabled: Bool }
    private struct ValueData: Decodable { let value: String }
    private struct LinkData: Decodable { let detail: String? }
    private struct DestructiveData: Decodable { let label: String }
}

// MARK: - ActionList Component

struct ActionListComponent: Decodable {
    let id: String
    let items: [ActionListItem]
}

struct ActionListItem: Decodable, Identifiable {
    let id: String
    let label: String
    let icon: String?
    let detail: String?
    var a11y: A11y?
}

// MARK: - StatusIndicator Component

struct StatusIndicatorComponent: Decodable {
    let id: String
    let icon: String?
    let title: String
    let detail: String?
    let status: Status
    var a11y: A11y?
}

enum Status: String, Decodable {
    case pending = "Pending"
    case inProgress = "InProgress"
    case success = "Success"
    case failed = "Failed"
    case warning = "Warning"
}

// MARK: - PinInput Component

struct PinInputComponent: Decodable {
    let id: String
    let label: String
    let length: Int
    let masked: Bool
    let validationError: String?
    var a11y: A11y?
}

// MARK: - QrCode Component

struct QrCodeComponent: Decodable {
    let id: String
    let data: String
    let mode: QrMode
    let label: String?
    var a11y: A11y?
}

enum QrMode: String, Decodable {
    case display = "Display"
    case scan = "Scan"
}

// MARK: - ConfirmationDialog Component

struct ConfirmationDialogComponent: Decodable {
    let id: String
    let title: String
    let message: String
    let confirmText: String
    let destructive: Bool
}

// MARK: - ShowToast Component

struct ShowToastComponent: Decodable {
    let id: String
    let message: String
    let undoActionId: String?
    let durationMs: UInt32
}

// MARK: - InlineConfirm Component

struct InlineConfirmComponent: Decodable {
    let id: String
    let warning: String
    let confirmText: String
    let cancelText: String
    let destructive: Bool
    var a11y: A11y?
}

// MARK: - EditableText Component

struct EditableTextComponent: Decodable {
    let id: String
    let label: String
    let value: String
    let editing: Bool
    let validationError: String?
    var a11y: A11y?
}

struct BannerComponent: Decodable {
    let text: String
    let actionLabel: String
    let actionId: String
    var a11y: A11y?
}

// MARK: - AvatarPreview Component

struct AvatarPreviewComponent: Decodable {
    let id: String
    let imageData: [UInt8]?
    let initials: String
    let bgColor: [UInt8]?
    let brightness: Float
    let editable: Bool
    let a11y: A11y?
}

// MARK: - Slider Component

struct SliderComponent: Decodable {
    let id: String
    let label: String
    let value: Float
    let min: Float
    let max: Float
    let step: Float
    let minIcon: String?
    let maxIcon: String?
    let a11y: A11y?
}

// MARK: - UserAction (Encodable for sending to core)

/// An action the user performed in the UI.
/// Maps to: `vauchi-core::ui::action::UserAction`
///
/// Uses custom encoding to match serde's `{"VariantName": {...}}` format.
enum UserAction: Encodable {
    case textChanged(componentId: String, value: String)
    case itemToggled(componentId: String, itemId: String)
    case actionPressed(actionId: String)
    case fieldVisibilityChanged(fieldId: String, groupId: String?, visible: Bool)
    case groupViewSelected(groupName: String?)
    case searchChanged(componentId: String, query: String)
    case listItemSelected(componentId: String, itemId: String)
    case settingsToggled(componentId: String, itemId: String)
    case undoPressed(actionId: String)
    case sliderChanged(componentId: String, valueMilli: Int32)

    // swiftlint:disable:next function_body_length
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: VariantKey.self)

        switch self {
        case let .textChanged(componentId, value):
            var nested = container.nestedContainer(keyedBy: TextChangedKeys.self, forKey: .textChanged)
            try nested.encode(componentId, forKey: .componentId)
            try nested.encode(value, forKey: .value)

        case let .itemToggled(componentId, itemId):
            var nested = container.nestedContainer(keyedBy: ItemToggledKeys.self, forKey: .itemToggled)
            try nested.encode(componentId, forKey: .componentId)
            try nested.encode(itemId, forKey: .itemId)

        case let .actionPressed(actionId):
            var nested = container.nestedContainer(keyedBy: ActionPressedKeys.self, forKey: .actionPressed)
            try nested.encode(actionId, forKey: .actionId)

        case let .fieldVisibilityChanged(fieldId, groupId, visible):
            var nested = container.nestedContainer(
                keyedBy: FieldVisibilityKeys.self, forKey: .fieldVisibilityChanged
            )
            try nested.encode(fieldId, forKey: .fieldId)
            try nested.encodeIfPresent(groupId, forKey: .groupId)
            try nested.encode(visible, forKey: .visible)

        case let .groupViewSelected(groupName):
            var nested = container.nestedContainer(
                keyedBy: GroupViewSelectedKeys.self, forKey: .groupViewSelected
            )
            try nested.encodeIfPresent(groupName, forKey: .groupName)

        case let .searchChanged(componentId, query):
            var nested = container.nestedContainer(
                keyedBy: SearchChangedKeys.self, forKey: .searchChanged
            )
            try nested.encode(componentId, forKey: .componentId)
            try nested.encode(query, forKey: .query)

        case let .listItemSelected(componentId, itemId):
            var nested = container.nestedContainer(
                keyedBy: ListItemSelectedKeys.self, forKey: .listItemSelected
            )
            try nested.encode(componentId, forKey: .componentId)
            try nested.encode(itemId, forKey: .itemId)

        case let .settingsToggled(componentId, itemId):
            var nested = container.nestedContainer(
                keyedBy: SettingsToggledKeys.self, forKey: .settingsToggled
            )
            try nested.encode(componentId, forKey: .componentId)
            try nested.encode(itemId, forKey: .itemId)

        case let .undoPressed(actionId):
            var nested = container.nestedContainer(
                keyedBy: UndoPressedKeys.self, forKey: .undoPressed
            )
            try nested.encode(actionId, forKey: .actionId)

        case let .sliderChanged(componentId, valueMilli):
            var nested = container.nestedContainer(
                keyedBy: SliderChangedKeys.self, forKey: .sliderChanged
            )
            try nested.encode(componentId, forKey: .componentId)
            try nested.encode(valueMilli, forKey: .valueMilli)
        }
    }

    private enum VariantKey: String, CodingKey {
        case textChanged = "TextChanged"
        case itemToggled = "ItemToggled"
        case actionPressed = "ActionPressed"
        case fieldVisibilityChanged = "FieldVisibilityChanged"
        case groupViewSelected = "GroupViewSelected"
        case searchChanged = "SearchChanged"
        case listItemSelected = "ListItemSelected"
        case settingsToggled = "SettingsToggled"
        case undoPressed = "UndoPressed"
        case sliderChanged = "SliderChanged"
    }

    private enum TextChangedKeys: String, CodingKey {
        case componentId = "component_id"
        case value
    }

    private enum ItemToggledKeys: String, CodingKey {
        case componentId = "component_id"
        case itemId = "item_id"
    }

    private enum ActionPressedKeys: String, CodingKey {
        case actionId = "action_id"
    }

    private enum FieldVisibilityKeys: String, CodingKey {
        case fieldId = "field_id"
        case groupId = "group_id"
        case visible
    }

    private enum GroupViewSelectedKeys: String, CodingKey {
        case groupName = "group_name"
    }

    private enum SearchChangedKeys: String, CodingKey {
        case componentId = "component_id"
        case query
    }

    private enum ListItemSelectedKeys: String, CodingKey {
        case componentId = "component_id"
        case itemId = "item_id"
    }

    private enum SettingsToggledKeys: String, CodingKey {
        case componentId = "component_id"
        case itemId = "item_id"
    }

    private enum UndoPressedKeys: String, CodingKey {
        case actionId = "action_id"
    }

    private enum SliderChangedKeys: String, CodingKey {
        case componentId = "component_id"
        case valueMilli = "value_milli"
    }
}

// MARK: - ActionResult

/// The result of handling a user action.
/// Maps to: `vauchi-core::ui::action::ActionResult`
enum ActionResult: Decodable {
    case updateScreen(ScreenModel)
    case navigateTo(ScreenModel)
    case validationError(componentId: String, message: String)
    case complete
    case startDeviceLink
    case startBackupImport
    case openContact(contactId: String)
    case editContact(contactId: String)
    case openUrl(url: String)
    case showAlert(title: String, message: String)
    case requestCamera
    case openEntryDetail(fieldId: String)
    case showToast(message: String, undoActionId: String?)
    case wipeComplete
    case exchangeCommands(commands: [ExchangeCommandDTO])
    case unknown

    init(from decoder: Decoder) throws {
        // Unit variants: "Complete", "StartDeviceLink", etc.
        if let container = try? decoder.singleValueContainer(),
           let stringValue = try? container.decode(String.self)
        {
            self = try Self.decodeUnitVariant(stringValue, codingPath: decoder.codingPath)
            return
        }

        // Struct variants: {"VariantName": {...}}
        let container = try decoder.container(keyedBy: VariantKey.self)
        self = try Self.decodeStructVariant(from: container, codingPath: decoder.codingPath)
    }

    private static func decodeUnitVariant(_ value: String, codingPath _: [CodingKey]) throws -> ActionResult {
        switch value {
        case "Complete": return .complete
        case "StartDeviceLink": return .startDeviceLink
        case "StartBackupImport": return .startBackupImport
        case "RequestCamera": return .requestCamera
        case "WipeComplete": return .wipeComplete
        // Unknown action result — ignore
        default: return .unknown
        }
    }

    private static func decodeStructVariant(
        from container: KeyedDecodingContainer<VariantKey>,
        codingPath _: [CodingKey]
    ) throws -> ActionResult {
        if container.contains(.updateScreen) {
            return try .updateScreen(container.decode(ScreenModel.self, forKey: .updateScreen))
        } else if container.contains(.navigateTo) {
            return try .navigateTo(container.decode(ScreenModel.self, forKey: .navigateTo))
        } else if container.contains(.validationError) {
            let error = try container.decode(ValidationErrorData.self, forKey: .validationError)
            return .validationError(componentId: error.componentId, message: error.message)
        } else if container.contains(.openContact) {
            let data = try container.decode(OpenContactData.self, forKey: .openContact)
            return .openContact(contactId: data.contactId)
        } else if container.contains(.openUrl) {
            let data = try container.decode(OpenUrlData.self, forKey: .openUrl)
            return .openUrl(url: data.url)
        } else if container.contains(.editContact) {
            let data = try container.decode(EditContactData.self, forKey: .editContact)
            return .editContact(contactId: data.contactId)
        } else if container.contains(.showAlert) {
            let data = try container.decode(ShowAlertData.self, forKey: .showAlert)
            return .showAlert(title: data.title, message: data.message)
        } else if container.contains(.openEntryDetail) {
            let data = try container.decode(OpenEntryDetailData.self, forKey: .openEntryDetail)
            return .openEntryDetail(fieldId: data.fieldId)
        } else if container.contains(.showToast) {
            let data = try container.decode(ShowToastData.self, forKey: .showToast)
            return .showToast(message: data.message, undoActionId: data.undoActionId)
        } else if container.contains(.exchangeCommands) {
            let data = try container.decode(ExchangeCommandsData.self, forKey: .exchangeCommands)
            return .exchangeCommands(commands: data.commands)
        }
        return .unknown
    }

    private enum VariantKey: String, CodingKey {
        case updateScreen = "UpdateScreen"
        case navigateTo = "NavigateTo"
        case validationError = "ValidationError"
        case openContact = "OpenContact"
        case editContact = "EditContact"
        case openUrl = "OpenUrl"
        case showAlert = "ShowAlert"
        case openEntryDetail = "OpenEntryDetail"
        case showToast = "ShowToast"
        case exchangeCommands = "ExchangeCommands"
    }

    private struct ValidationErrorData: Decodable {
        let componentId: String
        let message: String
    }

    private struct OpenContactData: Decodable {
        let contactId: String
    }

    private struct OpenUrlData: Decodable {
        let url: String
    }

    private struct EditContactData: Decodable {
        let contactId: String
    }

    private struct ShowAlertData: Decodable {
        let title: String
        let message: String
    }

    private struct OpenEntryDetailData: Decodable {
        let fieldId: String
    }

    private struct ShowToastData: Decodable {
        let message: String
        let undoActionId: String?
    }

    private struct ExchangeCommandsData: Decodable {
        let commands: [ExchangeCommandDTO]
    }
}

/// DTO for exchange commands from core (ADR-031).
/// Maps to: `vauchi-core::exchange::command::ExchangeCommand`
enum ExchangeCommandDTO: Decodable {
    case qrDisplay(data: String)
    case qrRequestScan
    case bleStartAdvertising(serviceUuid: String, payload: [UInt8])
    case bleStartScanning(serviceUuid: String)
    case bleStopScanning
    case bleConnect(deviceId: String)
    case bleWriteCharacteristic(uuid: String, data: [UInt8])
    case bleReadCharacteristic(uuid: String)
    case bleDisconnect
    case nfcActivate(payload: [UInt8])
    case nfcDeactivate
    case audioEmitChallenge(data: [UInt8])
    case audioListenForResponse(timeoutMs: UInt64)
    case audioStop
    case directSend(payload: [UInt8], isInitiator: Bool)
    case imagePickFromLibrary
    case imageCaptureFromCamera
    case imagePickFromFile
    case unknown

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let stringValue = try? container.decode(String.self)
        {
            switch stringValue {
            case "QrRequestScan": self = .qrRequestScan
            case "BleStopScanning": self = .bleStopScanning
            case "BleDisconnect": self = .bleDisconnect
            case "NfcDeactivate": self = .nfcDeactivate
            case "AudioStop": self = .audioStop
            case "ImagePickFromLibrary": self = .imagePickFromLibrary
            case "ImageCaptureFromCamera": self = .imageCaptureFromCamera
            case "ImagePickFromFile": self = .imagePickFromFile
            default: self = .unknown
            }
            return
        }

        let container = try decoder.container(keyedBy: CommandKey.self)
        if container.contains(.qrDisplay) {
            let data = try container.decode(QrDisplayData.self, forKey: .qrDisplay)
            self = .qrDisplay(data: data.data)
        } else if container.contains(.bleStartScanning) {
            let data = try container.decode(BleServiceData.self, forKey: .bleStartScanning)
            self = .bleStartScanning(serviceUuid: data.serviceUuid)
        } else if container.contains(.bleConnect) {
            let data = try container.decode(BleConnectData.self, forKey: .bleConnect)
            self = .bleConnect(deviceId: data.deviceId)
        } else if container.contains(.bleStartAdvertising) {
            let data = try container.decode(BleAdvertisingData.self, forKey: .bleStartAdvertising)
            self = .bleStartAdvertising(serviceUuid: data.serviceUuid, payload: data.payload)
        } else if container.contains(.bleWriteCharacteristic) {
            let data = try container.decode(BleCharacteristicData.self, forKey: .bleWriteCharacteristic)
            self = .bleWriteCharacteristic(uuid: data.uuid, data: data.data)
        } else if container.contains(.bleReadCharacteristic) {
            let data = try container.decode(BleReadData.self, forKey: .bleReadCharacteristic)
            self = .bleReadCharacteristic(uuid: data.uuid)
        } else if container.contains(.nfcActivate) {
            let data = try container.decode(NfcActivateData.self, forKey: .nfcActivate)
            self = .nfcActivate(payload: data.payload)
        } else if container.contains(.audioEmitChallenge) {
            let data = try container.decode(AudioChallengeData.self, forKey: .audioEmitChallenge)
            self = .audioEmitChallenge(data: data.data)
        } else if container.contains(.audioListenForResponse) {
            let data = try container.decode(AudioListenData.self, forKey: .audioListenForResponse)
            self = .audioListenForResponse(timeoutMs: data.timeoutMs)
        } else if container.contains(.directSend) {
            let data = try container.decode(DirectSendData.self, forKey: .directSend)
            self = .directSend(payload: data.payload, isInitiator: data.isInitiator)
        } else {
            self = .unknown
        }
    }

    private enum CommandKey: String, CodingKey {
        case qrDisplay = "QrDisplay"
        case bleStartAdvertising = "BleStartAdvertising"
        case bleStartScanning = "BleStartScanning"
        case bleConnect = "BleConnect"
        case bleWriteCharacteristic = "BleWriteCharacteristic"
        case bleReadCharacteristic = "BleReadCharacteristic"
        case nfcActivate = "NfcActivate"
        case audioEmitChallenge = "AudioEmitChallenge"
        case audioListenForResponse = "AudioListenForResponse"
        case directSend = "DirectSend"
    }

    private struct QrDisplayData: Decodable { let data: String }
    private struct BleServiceData: Decodable { let serviceUuid: String }
    private struct BleConnectData: Decodable { let deviceId: String }
    private struct BleAdvertisingData: Decodable { let serviceUuid: String; let payload: [UInt8] }
    private struct BleCharacteristicData: Decodable { let uuid: String; let data: [UInt8] }
    private struct BleReadData: Decodable { let uuid: String }
    private struct NfcActivateData: Decodable { let payload: [UInt8] }
    private struct AudioChallengeData: Decodable { let data: [UInt8] }
    private struct AudioListenData: Decodable { let timeoutMs: UInt64 }
    private struct DirectSendData: Decodable {
        let payload: [UInt8]
        let isInitiator: Bool

        // swiftlint:disable:next nesting
        enum CodingKeys: String, CodingKey {
            case payload
            case isInitiator = "is_initiator"
        }
    }
}
