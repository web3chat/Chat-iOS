//
//  LabelAlignment.swift
//  chat
//
//  Created by 陈健 on 2020/12/23.
//

import Foundation

struct LabelAlignment {
    let textAlignment: NSTextAlignment
    let textInsets: UIEdgeInsets
    
    init(textAlignment: NSTextAlignment, textInsets: UIEdgeInsets) {
        self.textAlignment = textAlignment
        self.textInsets = textInsets
    }
}

 extension LabelAlignment: Equatable {

    static func == (lhs: LabelAlignment, rhs: LabelAlignment) -> Bool {
        return lhs.textAlignment == rhs.textAlignment && lhs.textInsets == rhs.textInsets
    }

}
