//
//  DimeWidgetsBundle.swift
//  DimeWidgets
//
//  Entry point for the DimeWidgets WidgetKit extension — bundles all three
//  home-screen widgets defined in this target.
//

import SwiftUI
import WidgetKit

@main
struct DimeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        OverallBudgetWidget()
        RecentTransactionsWidget()
        InsightsWidget()
    }
}
