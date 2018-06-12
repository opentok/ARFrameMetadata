//
//  Data+fromArray.swift
//  ARFrameMetadata
//
//  Created by Roberto Perez Cubero on 12/06/2018.
//  Copyright © 2018 tokbox. All rights reserved.
//

import Foundation
extension Data {
    init<T>(fromArray values: [T]) {
        var values = values
        self.init(buffer: UnsafeBufferPointer(start: &values, count: values.count))
    }    
    func toArray<T>(type: T.Type) -> [T] {
        return self.withUnsafeBytes {
            [T](UnsafeBufferPointer(start: $0, count: self.count/MemoryLayout<T>.stride))
        }
    }
}
