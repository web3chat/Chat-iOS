//
//  SocketData.swift
//  chat
//
//  Created by 陈健 on 2021/1/16.
//

import Foundation

struct SocketData {
    typealias WrapData = Data
    typealias UnWrapData = (op: Int, seq: Int, ack: Int, body: Data)
    
    fileprivate typealias PlInt  = Int32
    fileprivate typealias HlInt  = Int16
    fileprivate typealias VerInt = Int16
    fileprivate typealias OpInt  = Int32
    fileprivate typealias SeqInt = Int32
    fileprivate typealias AckInt = Int32
    
    static private let plSize = MemoryLayout<SocketData.PlInt>.size
    static private let hlSize = MemoryLayout<SocketData.HlInt>.size
    static private let verSize = MemoryLayout<SocketData.VerInt>.size
    static private let opSize = MemoryLayout<SocketData.OpInt>.size
    static private let seqSize = MemoryLayout<SocketData.SeqInt>.size
    static private let ackSize = MemoryLayout<SocketData.AckInt>.size
    
    static private let headerLength = plSize + hlSize + verSize + opSize + seqSize + ackSize
    
    static private let plDataRange = 0...(plSize - 1)//0...3
    static private let hlDataRange = (plDataRange.upperBound + 1)...(plDataRange.upperBound + hlSize)//4...5
    
    static private let verDataRange = (hlDataRange.upperBound + 1)...(hlDataRange.upperBound + verSize)//6...7
    static private let opDataRange = (verDataRange.upperBound + 1)...(verDataRange.upperBound + opSize)//8...11
    static private let seqDataRange = (opDataRange.upperBound + 1)...(opDataRange.upperBound + seqSize)//12...15
    static private let ackDataRange = (seqDataRange.upperBound + 1)...(seqDataRange.upperBound + ackSize)//16...19
    
    static func wrapData(with op: Int, seq: Int, ack: Int, body: Data) -> WrapData {
        let packageLength = self.headerLength + body.count
        
        let pl = PlInt(packageLength).bigEndian
        let hl = HlInt(headerLength).bigEndian
        let ver = VerInt(1).bigEndian
        let op = OpInt(op).bigEndian
        let seq = SeqInt(seq).bigEndian
        let ack = AckInt(ack).bigEndian
        let body = body
        
        return pl.data + hl.data + ver.data + op.data + seq.data + ack.data + body
    }
    
    static func unwrap(data: WrapData) -> UnWrapData? {
        guard data.count >= self.headerLength else { return nil }
        
        let plData = data[plDataRange]
        let pl = PlInt.init(bigEndian: plData.PlInt)
        
        let hlData = data[hlDataRange]
        let hl = HlInt.init(bigEndian: hlData.HlInt)
        
//        let verData = data[verDataRange]
//        let ver = VerInt.init(bigEndian: verData.VerInt)
        
        let opData = data[opDataRange]
        let op = Int(OpInt.init(bigEndian: opData.OpInt))
        
        let seqData = data[seqDataRange]
        let seq = Int(SeqInt.init(bigEndian: seqData.SeqInt))
        
        let ackData = data[ackDataRange]
        let ack = Int(AckInt.init(bigEndian: ackData.AckInt))
        
        guard pl - PlInt(hl) > 0 else { return (op, seq, 0, Data.init()) }
        let bodyRange = (ackDataRange.upperBound + 1)...(data.count - 1)
        let body = data[bodyRange]
        return (op, seq, ack, body)
    }
}


private extension Data {
    var PlInt: SocketData.PlInt {
        get {
            return self.int32
        }
    }
    var HlInt: SocketData.HlInt {
        get {
            return self.int16
        }
    }
    var VerInt: SocketData.VerInt {
        get {
            return self.int16
        }
    }
    var OpInt: SocketData.OpInt {
        get {
            return self.int32
        }
    }
    var SeqInt: SocketData.SeqInt {
        get {
            return self.int32
        }
    }
    var AckInt: SocketData.AckInt {
        get {
            return self.int32
        }
    }
}
