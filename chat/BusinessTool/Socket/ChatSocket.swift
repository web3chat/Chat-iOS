//
//  ChatSocket.swift
//  chat
//
//  Created by fzm on 2021/1/16.
//

import UIKit
import Starscream

class ChatSocket {
    
    private let socket: Starscream.WebSocket
    
    weak var delegate: WebSocketDelegate? {
        didSet {
            self.socket.delegate = delegate
        }
    }
    
    let url: URL
    
    init(url: URL) {
        self.url = url
        var request = URLRequest.init(url: url)
        request.timeoutInterval = 10
        let socket = WebSocket.init(request: request)
        self.socket = socket
    }
    
    func connect() {
        self.socket.connect()
    }
    
    func disconnect(closeCode: UInt16 = CloseCode.normal.rawValue) {
        self.socket.disconnect(closeCode: closeCode)
    }
    
    func write(data: Data) {
        self.socket.write(data: data)
    }
}
