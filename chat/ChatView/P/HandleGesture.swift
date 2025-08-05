//
//  HandleGesture.swift
//  chat
//
//  Created by 陈健 on 2020/12/22.
//

import Foundation

protocol HandleGesture: NSObjectProtocol {
    func handleTapGesture(_ gesture: UIGestureRecognizer)
    func handleLongPressGesture(_ longPressGesture: UILongPressGestureRecognizer)
}


