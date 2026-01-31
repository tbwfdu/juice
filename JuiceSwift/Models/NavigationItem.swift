//
//  NavigationItem.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 27/1/2026.
//
import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case landing
    case search
    case updates
    case importApps
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .landing: return "Landing"
        case .search: return "Search"
        case .updates: return "Updates"
        case .importApps: return "Import"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .landing: return "house"
        case .search: return "magnifyingglass"
        case .updates: return "arrow.triangle.2.circlepath"
        case .importApps: return "tray.and.arrow.down"
        case .settings: return "gearshape"
        }
    }

    static var mainCases: [NavigationItem] {
        [.landing, .search, .updates, .importApps]
    }
}
