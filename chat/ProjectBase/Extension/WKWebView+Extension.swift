//
//  WKWebView+Extension.swift
//  xls
//
//  Created by fzm on 2020/10/29.
//  Copyright © 2020 fzm. All rights reserved.
//

import Foundation
import WebKit

extension WKWebView {
    func goToFirstItem() {
        guard self.backForwardList.backList.count > 0,
              let firstItem = self.backForwardList.item(at: -self.backForwardList.backList.count) else { return }
        self.go(to: firstItem)
    }
}
