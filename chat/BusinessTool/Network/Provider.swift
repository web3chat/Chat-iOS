//
//  Provider.swift
//  xls
//
//  Created by 陈健 on 2020/8/21.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation
import Moya
import SwiftyJSON

class Provider {
    typealias SuccessBlock = (JSON) -> ()
    typealias FailureBlock = (Error) -> ()
    
    private static let sharedInstance = Provider.init()

    private class func shared() -> Provider {
        return sharedInstance
    }
    
    private init() { }
//    #if DEBUG
//    private let moyaProvider = MoyaProvider<MultiTarget>.init(callbackQueue: .main, plugins: [NetworkLoggerPlugin.init(configuration: .init(logOptions: .verbose))])
//    #else
    private let moyaProvider = MoyaProvider<MultiTarget>.init(callbackQueue: .main)
//    #endif
    
    @discardableResult
    class func request(_ target: XLSTargetType, successBlock: SuccessBlock?, failureBlock: FailureBlock?) -> Cancellable {
        let provider = Provider.shared()
        return provider.moyaProvider.request(MultiTarget.target(target)) { (result) in
            switch target.validation(result) {
            case .success(let data):
                successBlock?(data)
            case .failure(let error):
                failureBlock?(error)
            }
        }
    }
    
    class func requestFormData(_ target: XLSTargetType, successBlock: SuccessBlock?, failureBlock: FailureBlock?) -> Cancellable {
        let provider = Provider.shared()
        return provider.moyaProvider.request(MultiTarget(target)) { (result) in
            switch target.validation(result) {
            case .success(let data):
                successBlock?(data)
            case .failure(let error):
                failureBlock?(error)
            }
        }
    }
    
}

