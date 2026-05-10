//
//  Double.swift
//  GraphKit
//
//  Created by Illia Senchukov on 08.05.2026.
//

import Foundation

extension Double {

    /// convert value [-1; 1] to [0; 1]
    var displayToNormalized: Double {
        (self + 1) / 2
    }

    /// convert value [0;1] to [-1, 1]
    var displayNormalized: Double {
        2 * self - 1
    }

}
