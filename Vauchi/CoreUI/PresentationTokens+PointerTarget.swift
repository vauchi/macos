// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
//
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension PresentationTokens {
    /// Every decoded `PresentationTokens` carries `minimum_target_size`,
    /// but some chrome renders before any surface — and its tokens — exist
    /// (the context command bar, `ContextCommandBarView`). `48` is
    /// Android's touch-target floor, not Apple's 44: the cross-frontend
    /// review's F4 correction argues 44 is Apple's floor rather than an
    /// age-friendly one, so the resolved default agrees with Core's own
    /// tokens rather than repeating the lower platform minimum.
    static func minimumTargetSize(from tokens: PresentationTokens?) -> CGFloat {
        tokens.map { CGFloat($0.minimumTargetSize) } ?? 48
    }
}
