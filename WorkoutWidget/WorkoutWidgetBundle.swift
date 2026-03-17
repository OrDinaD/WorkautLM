//
//  WorkoutWidgetBundle.swift
//  WorkoutWidget
//
//  Created by Влад on 17.03.26.
//

import WidgetKit
import SwiftUI

@main
struct WorkoutWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutWidget()
        WorkoutWidgetControl()
        WorkoutWidgetLiveActivity()
    }
}
