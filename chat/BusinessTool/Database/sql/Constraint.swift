//
//  Constraint.swift
//  chat
//
//  Created by fzm on 2021/1/13.
//

import Foundation
import WCDBSwift

typealias ConstraintBlock = (Constraint) -> ()

class Constraint {
    var condition: WCDBSwift.Condition?
    var orderBy : [WCDBSwift.OrderBy]?
    var limit : WCDBSwift.Limit?
    var offset : WCDBSwift.Offset?
}
