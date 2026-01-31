//
//  RightPanelTab.swift
//  JuiceSwift
//
//  Created by Pete Lindley on 27/1/2026.
//

import SwiftUI

enum RightPanelTab: String, CaseIterable, Identifiable {
    case queue
    case results

    var id: String { rawValue }
}
