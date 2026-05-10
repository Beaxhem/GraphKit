//
//  CGPoint.swift
//  GraphKit
//
//  Created by Illia Senchukov on 08.05.2026.
//

import Foundation

extension CGPoint {

    var simd: SIMD2<Double> {
        .init(x: Double(x), y: Double(y))
    }

}
