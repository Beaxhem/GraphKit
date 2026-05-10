//
//  CGSize.swift
//  GraphKit
//
//  Created by Illia Senchukov on 08.05.2026.
//

import Foundation
import CoreGraphics

extension CGSize {

    var simd: SIMD2<Double> {
        .init(Double(width), Double(height))
    }

}
