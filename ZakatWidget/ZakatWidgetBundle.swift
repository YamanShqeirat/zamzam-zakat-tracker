//
//  ZakatWidgetBundle.swift
//  ZakatWidget
//
//  Created by Yaman Shqeirat on 5/13/26.
//

import WidgetKit
import SwiftUI

/// Every chart in the app has a widget here:
///   • ZakatWidget            — hawl countdown ring (small) / wealth distribution donut (medium)
///   • HijriCalendarWidget    — the lunar month ring
///   • WealthTrendWidget      — wealth vs nisab over time
///   • ZakatGivingWidget      — zakat given per Hijri year
///   • AccountBalancesWidget  — per-account end-of-month balances and deltas
///   • BudgetFlowWidget       — income vs expenses, by year and by month
///   • ExpenseCategoryWidget  — expenses by category
@main
struct ZakatWidgetBundle: WidgetBundle {
    var body: some Widget {
        ZakatWidget()
        HijriCalendarWidget()
        WealthTrendWidget()
        ZakatGivingWidget()
        AccountBalancesWidget()
        BudgetFlowWidget()
        ExpenseCategoryWidget()
    }
}
