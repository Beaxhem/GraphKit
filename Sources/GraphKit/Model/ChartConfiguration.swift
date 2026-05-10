//
//  ChartConfiguration.swift
//  GraphKit
//
//  Created by Illia Senchukov on 08.05.2026.
//

public struct ChartConfiguration {
    let lineWidth: Float
    let useSampling: Bool
    let isZoomEnabled: Bool
    let isPanGestureEnabled: Bool

    public init(lineWidth: Float, useSampling: Bool, isZoomEnabled: Bool, isPanGestureEnabled: Bool) {
        self.lineWidth = lineWidth
        self.useSampling = useSampling
        self.isZoomEnabled = isZoomEnabled
        self.isPanGestureEnabled = isPanGestureEnabled
    }
}
