//
//  PointsStorage.swift
//  GraphKit
//
//  Created by Illia Senchukov on 08.05.2026.
//

import Foundation

public struct FallbackValue<T> {

    private let storedValue: T?

    private var custom: T?

    public var value: T? {
        custom ?? storedValue
    }

    init(storedValue: T?, custom: T? = nil) {
        self.storedValue = storedValue
        self.custom = custom
    }

    mutating func setCustom(_ newValue: T?) {
        self.custom = newValue
    }

}

@Observable
public final class PointsStorage: @unchecked Sendable {

    public var dataPoints: [Double] = [] {
        didSet {
            findMinMax()
            normalize()
        }
    }

    public private(set) var normalizedDataPoints: [Double]?

    public private(set) var minValue = FallbackValue<Double>(storedValue: nil)

    public private(set) var maxValue = FallbackValue<Double>(storedValue: nil)

    @ObservationIgnored
    private var normalizationTask: Task<Void, Never>?

    public init(dataPoints: [Double] = []) {
        self.dataPoints = dataPoints
        findMinMax()
        normalize()
    }

}

extension PointsStorage {

    func updateMinValue(_ newValue: Double?) {
        minValue.setCustom(newValue)

        normalize()
    }

    func updateMaxValue(_ newValue: Double?) {
        maxValue.setCustom(newValue)

        normalize()
    }

    func reset() {
        minValue = .init(storedValue: -.infinity)
        maxValue = .init(storedValue: .infinity)
        dataPoints = []
        normalizedDataPoints = []
    }

}

private extension PointsStorage {

    func normalize() {
        guard !dataPoints.isEmpty else {
            minValue = .init(storedValue: -.infinity)
            maxValue = .init(storedValue: .infinity)
            normalizedDataPoints = []
            return
        }

        normalizationTask?.cancel()
        normalizationTask = Task.detached { [weak self] in
            guard let self, let minValue = minValue.value, let maxValue = maxValue.value else { return }

            let minDisplayRange: Double = -0.97
            let maxDisplayRange: Double = 0.9

            let range = (maxDisplayRange - minDisplayRange) / (maxValue - minValue)

            var normalizedDataPoints: [Double] = []
            normalizedDataPoints.reserveCapacity(dataPoints.count)

            for x in self.dataPoints {
                if Task.isCancelled { return }

                let n = minDisplayRange + ((x - minValue) * range)
                normalizedDataPoints.append(n)
            }

            Task { @MainActor in
                if Task.isCancelled { return }

                self.normalizedDataPoints = normalizedDataPoints
            }
        }
    }

    func findMinMax() {
        var minValue = Double.greatestFiniteMagnitude
        var maxValue = Double.leastNormalMagnitude

        for dataPoint in dataPoints {
            if Task.isCancelled { return }
            if dataPoint < minValue {
                minValue = dataPoint
            }
            if dataPoint > maxValue {
                maxValue = dataPoint
            }
        }

        self.minValue = .init(storedValue: minValue)
        self.maxValue = .init(storedValue: maxValue)
    }

}
