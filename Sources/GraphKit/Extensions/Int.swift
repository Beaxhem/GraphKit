//
//  Int.swift
//  GraphKit
//
//  Created by Illia Senchukov on 08.05.2026.
//

import Foundation

extension Int {

    enum DataStepRoundingRule {
        case up, down
    }

    func roundTo(dataStep: Int, rule: DataStepRoundingRule) -> Int {
        let offset = (Double(self + dataStep) / Double(dataStep)).truncatingRemainder(dividingBy: 1)
        return switch rule {
        case .up:
            Int(Double(self) + Double(dataStep) * offset)
        case .down:
            Int(Double(self) - Double(dataStep) * offset)
        }
    }

}
