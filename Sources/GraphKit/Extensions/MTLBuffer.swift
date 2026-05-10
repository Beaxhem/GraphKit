//
//  File.swift
//  GraphKit
//
//  Created by Illia Senchukov on 08.05.2026.
//

import MetalKit

extension MTLBuffer? {

    mutating func update<T>(with data: T, device: MTLDevice?, options: MTLResourceOptions = []) {
        withUnsafePointer(to: data) { dataPtr in
            if let ptr = self?.contents() {
                memcpy(ptr, dataPtr, MemoryLayout<T>.size)
            } else {
                self = device?.makeBuffer(bytes: dataPtr, length: MemoryLayout<T>.stride, options: options)
            }
        }
    }

}
