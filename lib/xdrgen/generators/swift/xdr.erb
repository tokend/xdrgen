//
//  XDR.swift
//  StellarSDK
//
//  Created by Laptop on 2/2/18.
//  Adapted from StellarKit.XDRCodable.swift
//  Copyright © 2018 Armonia. All rights reserved.
//
//  License from StellarKit
//
//  MIT License
//
//  Copyright (c) 2018 Kin Foundation
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.


import Foundation

// Handy extensions

extension Data {
    var base64: String { return self.base64EncodedString() }
}

extension Data {
    var pad4: Data {
        let pad = self.count % 4
        let zeroes = Data(repeating: 0, count: pad)
        return self + zeroes
    }
}

// bitWidth is available in Swift 4.0

// Size of type
extension UInt   { static var bitWidth:  Int { return MemoryLayout<UInt>.size   } }
extension UInt8  { static var bitWidth:  Int { return MemoryLayout<UInt8>.size  } }
extension UInt16 { static var bitWidth:  Int { return MemoryLayout<UInt16>.size } }
extension UInt32 { static var bitWidth:  Int { return MemoryLayout<UInt32>.size } }
extension UInt64 { static var bitWidth:  Int { return MemoryLayout<UInt64>.size } }
extension Int    { static var bitWidth:  Int { return MemoryLayout<Int>.size    } }
extension Int8   { static var bitWidth:  Int { return MemoryLayout<Int8>.size   } }
extension Int16  { static var bitWidth:  Int { return MemoryLayout<Int16>.size  } }
extension Int32  { static var bitWidth:  Int { return MemoryLayout<Int32>.size  } }
extension Int64  { static var bitWidth:  Int { return MemoryLayout<Int64>.size  } }

// Size of instance
extension UInt   { var bitWidth: Int { return MemoryLayout.size(ofValue: self) } }
extension UInt8  { var bitWidth: Int { return MemoryLayout.size(ofValue: self) } }
extension UInt16 { var bitWidth: Int { return MemoryLayout.size(ofValue: self) } }
extension UInt32 { var bitWidth: Int { return MemoryLayout.size(ofValue: self) } }
extension UInt64 { var bitWidth: Int { return MemoryLayout.size(ofValue: self) } }
extension Int    { var bitWidth: Int { return MemoryLayout.size(ofValue: self) } }
extension Int8   { var bitWidth: Int { return MemoryLayout.size(ofValue: self) } }
extension Int16  { var bitWidth: Int { return MemoryLayout.size(ofValue: self) } }
extension Int32  { var bitWidth: Int { return MemoryLayout.size(ofValue: self) } }
extension Int64  { var bitWidth: Int { return MemoryLayout.size(ofValue: self) } }


public protocol XDREncodable {
    var xdr: Data { get }
    func toXDR(count: Int32) -> Data
}

public protocol XDRDecodable {
    init(xdrData: inout Data, count: Int32)
}

public protocol XDRCodable: XDREncodable, XDRDecodable { }

public protocol XDREncodableStruct: XDREncodable { }

extension XDREncodable {
    public var xdr: Data { return self.toXDR(count: 0) }
}

extension UInt8: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        return Data(bytes: [self])
    }
    
    public init(xdrData: inout Data, count: Int32 = 0) {
        var n: UInt8 = 0
        
        let count = UInt8.bitWidth / UInt8.bitWidth
        
        xdrData.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<count {
                //n *= 256
                n += UInt8(bp.advanced(by: i).pointee)
            }
        }
        
        self = n
    }
}

extension Int16: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var n = UInt16(bitPattern: self)
        var a = [UInt8]()
        
        let divisor = UInt16(UInt8.max) + 1
        for _ in 0..<(self.bitWidth / UInt8.bitWidth) {
            a.append(UInt8(n % divisor))
            n /= divisor
        }
        
        return Data(bytes: a.reversed())
    }
    
    public init(xdrData: inout Data, count: Int32 = 0) {
        var n: UInt16 = 0
        
        let count = UInt16.bitWidth / UInt8.bitWidth
        
        xdrData.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<count {
                n *= 256
                n += UInt16(bp.advanced(by: i).pointee)
            }
        }
        
        (0..<count).forEach { _ in xdrData.remove(at: 0) }
        
        self = Int16(bitPattern: n)
    }
}

extension UInt16: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var val = self
        let div = UInt16(UInt8.max) + 1
        var all = [UInt8]()
        
        for _ in 0..<(self.bitWidth / UInt8.bitWidth) {
            all.append(UInt8(val % div))
            val /= div
        }
        
        return Data(bytes: all.reversed())
    }
    
    public init(xdrData: inout Data, count: Int32 = 0) {
        var n: UInt16 = 0
        
        let count = UInt16.bitWidth / UInt8.bitWidth
        
        xdrData.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<count {
                n *= 256
                n += UInt16(bp.advanced(by: i).pointee)
            }
        }
        
        (0..<count).forEach { _ in xdrData.remove(at: 0) }
        
        self = n
    }
}

extension Int32: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var n = UInt32(bitPattern: self)
        var a = [UInt8]()
        
        let divisor = UInt32(UInt8.max) + 1
        for _ in 0..<(self.bitWidth / UInt8.bitWidth) {
            a.append(UInt8(n % divisor))
            n /= divisor
        }
        
        return Data(bytes: a.reversed())
    }
    
    public init(xdrData: inout Data, count: Int32 = 0) {
        var n: UInt32 = 0
        
        let count = UInt32.bitWidth / UInt8.bitWidth
        
        xdrData.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<count {
                n *= 256
                n += UInt32(bp.advanced(by: i).pointee)
            }
        }
        
        (0..<count).forEach { _ in xdrData.remove(at: 0) }
        
        self = Int32(bitPattern: n)
    }
}

extension UInt32: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var n = self
        var a = [UInt8]()
        
        let divisor = UInt32(UInt8.max) + 1
        for _ in 0..<(self.bitWidth / UInt8.bitWidth) {
            a.append(UInt8(n % divisor))
            n /= divisor
        }
        
        return Data(bytes: a.reversed())
    }
    
    public init(xdrData: inout Data, count: Int32 = 0) {
        var n: UInt32 = 0
        
        let count = UInt32.bitWidth / UInt8.bitWidth
        
        xdrData.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<count {
                n *= 256
                n += UInt32(bp.advanced(by: i).pointee)
            }
        }
        
        (0..<count).forEach { _ in xdrData.remove(at: 0) }
        
        self = n
    }
}

extension Int64: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var n = UInt64(bitPattern: self)
        var a = [UInt8]()
        
        let divisor = UInt64(UInt8.max) + 1
        for _ in 0..<(self.bitWidth / UInt8.bitWidth) {
            a.append(UInt8(n % divisor))
            n /= divisor
        }
        
        return Data(bytes: a.reversed())
    }
    
    public init(xdrData: inout Data, count: Int32 = 0) {
        var n: UInt64 = 0
        
        let count = UInt64.bitWidth / UInt8.bitWidth
        
        xdrData.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<count {
                n *= 256
                n += UInt64(bp.advanced(by: i).pointee)
            }
        }
        
        (0..<count).forEach { _ in xdrData.remove(at: 0) }
        
        self = Int64(bitPattern: n)
    }
}

extension UInt64: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var n = self
        var a = [UInt8]()
        
        let divisor = UInt64(UInt8.max) + 1
        for _ in 0..<(self.bitWidth / UInt8.bitWidth) {
            a.append(UInt8(n % divisor))
            n /= divisor
        }
        
        return Data(bytes: a.reversed())
    }
    
    public init(xdrData: inout Data, count: Int32 = 0) {
        var n: UInt64 = 0
        
        let count = UInt64.bitWidth / UInt8.bitWidth
        
        xdrData.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<count {
                n *= 256
                n += UInt64(bp.advanced(by: i).pointee)
            }
        }
        
        (0..<count).forEach { _ in xdrData.remove(at: 0) }
        
        self = n
    }
}

extension Bool: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        return Int32(self ? 1 : 0).toXDR()
    }
    
    public init(xdrData: inout Data, count: Int32 = 0) {
        let b = Int32(xdrData: &xdrData)
        self = b != 0
    }
}

extension Data: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var xdr = Int32(self.count).toXDR()
        xdr.append(self)
        
        return xdr
    }
    
    public init(xdrData: inout Data, count: Int32 = 0) {
        let length = count > 0 ? UInt32(count) : UInt32(xdrData: &xdrData)
        
        var d = Data()
        for _ in 0..<length {
            d.append(xdrData.remove(at: 0))
        }
        
        self = d
    }
}

extension String: XDRCodable {
    public func toXDR(count: Int32 = 0) -> Data {
        let length = Int32(self.lengthOfBytes(using: .utf8))
        
        var xdr = length.toXDR()
        xdr.append(self.data(using: .utf8)!)
        
        let extraBytes = length % 4
        if extraBytes > 0 {
            for _ in 0..<(4 - extraBytes) {
                xdr.append(contentsOf: [0])
            }
        }
        
        return xdr
    }
    
    public init(xdrData: inout Data, count: Int32 = 0) {
        let length = Int32(xdrData: &xdrData)
        
        let d = xdrData.subdata(in: 0..<Int(length))
        
        self = String(bytes: d, encoding: .utf8)!
        
        let mod = length % 4
        let extraBytes = mod == 0 ? 0 : 4 - mod
        
        (0..<(length + extraBytes)).forEach { _ in xdrData.remove(at: 0) }
    }
}

extension Array: XDREncodable {
    public func toXDR(count: Int32 = 0) -> Data {
        let length = UInt32(self.count)
        
        var xdr = count == 0 ? length.toXDR() : Data()
        
        forEach {
            if let e = $0 as? XDREncodable {
                xdr.append(e.toXDR(count: 0))
            }
        }
        
        return xdr
    }
}

extension Array where Element: XDRDecodable {
    public init(xdrData: inout Data, count: Int32 = 0) {
        let length = count > 0 ? UInt32(count) : UInt32(xdrData: &xdrData)
        
        var a = [Element]()
        
        (0..<length).forEach { _ in a.append(Element.init(xdrData: &xdrData, count: 0)) }
        
        self = a
    }
}

extension Optional: XDREncodable {
    public func toXDR(count: Int32 = 0) -> Data {
        var xdr = Data()
        
        switch self {
        case .some(let a):
            if let encodable = a as? XDREncodable {
                xdr += Int32(1).toXDR() + encodable.toXDR(count: 0)
            }
        case nil:
            xdr += Int32(0).toXDR()
        }
        
        return xdr
    }
}

public struct ArrayFixed<T: XDREncodable>: Sequence {
    public private(set) var list: Array<T>
    
    public init(_ array: [T]) {
        self.list = array
    }
    
    public subscript(_ index: Int) -> T {
        return list[index]
    }
    
    public func makeIterator() -> AnyIterator<T> {
        var index = 0
        
        return AnyIterator {
            let element: T? = index < self.list.count ? self[index] : nil
            index += 1
            
            return element
        }
    }
}

extension ArrayFixed: XDREncodable, CustomDebugStringConvertible {
    public func toXDR(count: Int32 = 0) -> Data {
        return list.toXDR(count: Int32(list.count))
    }

    public var debugDescription: String {
        return list.debugDescription
    }
}

public struct DataFixed: XDREncodable, Equatable, CustomDebugStringConvertible {
    public private(set) var data: Data
    
    public init(_ data: Data, size: Int = 0) {
        self.data = data
        if size > 0 && size - data.count > 0 { // Pad with zeroes
            self.data.append(contentsOf: Array<UInt8>(repeating: 0, count: size - data.count))
        }
    }

    public func toXDR(count: Int32 = 0) -> Data {
        return data
    }

    public static func ==(lhs: DataFixed, rhs: DataFixed) -> Bool {
        return lhs.data == rhs.data
    }
    
    public var debugDescription: String {
        return data.debugDescription
    }
}

extension XDREncodableStruct {
    public func toXDR(count: Int32 = 0) -> Data {
        var xdr = Data()
        
        for (_, value) in Mirror(reflecting: self).children {
            if let value = value as? XDREncodable {
                xdr.append(value.toXDR(count: 0))
            }
        }
        
        return xdr
    }
}


// END
