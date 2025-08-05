//
//  BackupAPI.swift
//  chat
//
//  Created by 陈健 on 2021/1/29.
//

import Foundation
import Moya

enum BackupAPI {
    case phoneQuery(area: String, phone: String)
    case emailQuery(email: String)
    case phoneBinding(area: String, phone: String, code: String, mnemonic: String)
    case emailBinding(email: String, code: String, mnemonic: String)
    case editMnemonic(mnemonic: String)
    case phoneRetrieve(area: String, phone: String, code: String)
    case emailRetrieve(email: String, code: String)
    case addressRetrieve(address: String)
    case getAddress(_ phoneOrEmail: String)// 通过手机或邮箱得到地址
}

extension BackupAPI: XLSTargetType {
    
    var baseURL: URL {
        return URL.init(string: BackupURL)  ?? URL.init(string: "https://api.unknow-error.com")!
    }
    
    var parameters: [String : Any] {
        switch self {
        case .phoneQuery(let area, let phone):
            return ["area": area, "phone": phone]
        case .emailQuery(let email):
            return ["email": email]
        case .phoneBinding(let area, let phone, let code, let mnemonic):
            return ["area": area, "phone": phone, "code": code, "mnemonic": mnemonic]
        case .emailBinding(let email, let code, let mnemonic):
            return ["email": email, "code": code, "mnemonic": mnemonic]
        case .editMnemonic(let mnemonic):
            return ["mnemonic": mnemonic]
        case .phoneRetrieve(let area, let phone, let code):
            return ["area": area, "phone": phone, "code": code]
        case .emailRetrieve(let email, let code):
            return ["email": email, "code": code]
        case .addressRetrieve(let address):
            return ["address": address]
        case .getAddress(let phone):
            return ["query": phone]
        }
    }
    var method: Moya.Method {
        return .post
    }
    
    var path: String {
        switch self {
        case .phoneQuery:
            return "/backup/phone-query"
        case .emailQuery:
            return "/backup/email-query"
        case .phoneBinding:
            return "/backup/phone-binding"
        case .emailBinding:
            return "/backup/email-binding"
        case .editMnemonic:
            return "/backup/edit-mnemonic"
        case .phoneRetrieve:
            return "/backup/phone-retrieve"
        case .emailRetrieve:
            return "/backup/email-retrieve"
        case .addressRetrieve:
            return "/backup/address-retrieve"
        case .getAddress:
            return "/backup/get-address"
        }
    }
}
