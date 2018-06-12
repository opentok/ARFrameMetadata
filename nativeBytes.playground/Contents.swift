//: Playground - noun: a place where people can play

import UIKit

extension Float {
    func toBigEndianByteArray() -> UnsafeBufferPointer<UInt8> {
        var bytes = bitPattern.bigEndian
        let count = MemoryLayout<UInt32>.size
        return withUnsafePointer(to: &bytes, {
            $0.withMemoryRebound(to: UInt8.self, capacity: count, {
                UnsafeBufferPointer(start: $0, count: count)
            })
        })
    }
}

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

var data = Data(fromArray: [Float(1.2), Float(2.3)])
print("\(data)")

let values = data.toArray(type: Float.self)

