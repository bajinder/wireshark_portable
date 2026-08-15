// DeepworkActivityWidgetBundle.swift
// DeepworkActivity (widget extension)
//
// v1 ships a single widget: the Live Activity that mirrors the running
// timer on the lock screen and in the Dynamic Island. There is no
// home-screen widget in scope for v1.

import WidgetKit
import SwiftUI

@main
struct DeepworkActivityWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeepworkLiveActivityWidget()
    }
}
