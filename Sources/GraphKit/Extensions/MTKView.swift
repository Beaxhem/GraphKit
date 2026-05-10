//
//  MTKView.swift
//  GraphKit
//
//  Created by Illia Senchukov on 08.05.2026.
//

import MetalKit

extension MTKView {

    func selectSampleCount() {
        let sampleCounts = [4, 2]
        for sampleCount in sampleCounts {
            if device?.supportsTextureSampleCount(sampleCount) == true {
                self.sampleCount = sampleCount
                break
            }
        }
    }

}
