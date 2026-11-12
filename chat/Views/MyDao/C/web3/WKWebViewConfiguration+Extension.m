//
//  WKWebViewConfiguration+Extension.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2023/9/5.
//  Copyright © 2023 fzm. All rights reserved.
//

#import "WKWebViewConfiguration+Extension.h"
#import <WebKit/WebKit.h>
#import <Foundation/Foundation.h>

@implementation WKWebViewConfiguration (Extension)

+ (WKWebViewConfiguration *)initBroswerAddr:(NSString *)addr rpcUrl:(NSString *)rpcUrl chainId:(NSInteger)chainID {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
   
    NSString *js = @"";
    NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"AlphaWalletWeb3Provider" ofType:@"bundle"];
    NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
//    isMetaMask: true,
    NSString *filepath = [bundle pathForResource:@"AlphaWallet-min" ofType:@"js"];
    NSError *error;
    js = [js stringByAppendingString:[NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:&error]];
    
    js = [js stringByAppendingString:[self stringWithAddr:addr rpcUrl:rpcUrl chainId:chainID]];
    
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:js injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:true];
    [config.userContentController addUserScript:userScript];
    
    [self injectJsToConfig:config];
    
    
    return config;
}


+ (NSString *)stringWithAddr:(NSString*)addressHex rpcUrl:(NSString *)rpcUrl chainId:(NSInteger )chainID{
    
    return [NSString stringWithFormat:@"""const addressHex = \"%@\"\n  const rpcURL = \"%@\"\n  const chainID = \"%li\"\n\n  function executeCallback (id, error, value) {\n      AlphaWallet.executeCallback(id, error, value)\n  }\n\n  AlphaWallet.init(rpcURL, {\n      getAccounts: function (cb) { cb(null, [addressHex]) },\n      processTransaction: function (tx, cb){\n          console.log(\'signing a transaction\', tx)\n          const { id = 8888 } = tx\n          AlphaWallet.addCallback(id, cb)\n          webkit.messageHandlers.sendTransaction.postMessage({\"name\": \"sendTransaction\", \"object\":     tx, id: id})\n      },\n      signMessage: function (msgParams, cb) {\n          const { data } = msgParams\n          const { id = 8888 } = msgParams\n          console.log(\"signing a message\", msgParams)\n          AlphaWallet.addCallback(id, cb)\n          webkit.messageHandlers.signMessage.postMessage({\"name\": \"signMessage\", \"object\": { data }, id:    id} )\n      },\n      signPersonalMessage: function (msgParams, cb) {\n          const { data } = msgParams\n          const { id = 8888 } = msgParams\n          console.log(\"signing a personal message\", msgParams)\n          AlphaWallet.addCallback(id, cb)\n          webkit.messageHandlers.signPersonalMessage.postMessage({\"name\": \"signPersonalMessage\", \"object\":  { data }, id: id})\n      },\n      signTypedMessage: function (msgParams, cb) {\n          const { data } = msgParams\n          const { id = 8888 } = msgParams\n          console.log(\"signing a typed message\", msgParams)\n          AlphaWallet.addCallback(id, cb)\n          webkit.messageHandlers.signTypedMessage.postMessage({\"name\": \"signTypedMessage\", \"object\":     { data }, id: id})\n      },\n  signTransaction: function (msgParams, cb) {\n          const { data } = msgParams\n          const { id = 8888 } = msgParams\n          console.log(\"signing a typed message\", msgParams)\n          AlphaWallet.addCallback(id, cb)\n          webkit.messageHandlers.signTypedMessage.postMessage({\"name\": \"signTransaction\", \"object\":     { data }, id: id})\n      },\n     ethCall: function (msgParams, cb) {\n          const data = msgParams\n          const { id = Math.floor((Math.random() * 100000) + 1) } = msgParams\n          console.log(\"eth_call\", msgParams)\n          AlphaWallet.addCallback(id, cb)\n          webkit.messageHandlers.ethCall.postMessage({\"name\": \"ethCall\", \"object\": data, id: id})\n      },\n      walletAddEthereumChain: function (msgParams, cb) {\n          const data = msgParams\n          const { id = Math.floor((Math.random() * 100000) + 1) } = msgParams\n          console.log(\"walletAddEthereumChain\", msgParams)\n          AlphaWallet.addCallback(id, cb)\n          webkit.messageHandlers.walletAddEthereumChain.postMessage({\"name\": \"walletAddEthereumChain\", \"object\": data, id: id})\n      },\n      walletSwitchEthereumChain: function (msgParams, cb) {\n          const data = msgParams\n          const { id = Math.floor((Math.random() * 100000) + 1) } = msgParams\n          console.log(\"walletSwitchEthereumChain\", msgParams)\n          AlphaWallet.addCallback(id, cb)\n          webkit.messageHandlers.walletSwitchEthereumChain.postMessage({\"name\": \"walletSwitchEthereumChain\", \"object\": data, id: id})\n      },\n      enable: function() {\n         return new Promise(function(resolve, reject) {\n             //send back the coinbase account as an array of one\n             resolve([addressHex])\n         })\n      }\n  }, {\n      address: addressHex,\n      networkVersion: \"0x\" + parseInt(chainID).toString(16) || null\n  })\n\n  web3.setProvider = function () {\n      console.debug(\'AlphaWallet Wallet - overrode web3.setProvider\')\n  }\n\n  web3.eth.defaultAccount = addressHex\n\n  web3.version.getNetwork = function(cb) {\n      cb(null, chainID)\n  }\n\n web3.eth.getCoinbase = function(cb) {\n  return cb(null, addressHex)\n}\nwindow.ethereum = web3.currentProvider\n  \n// So we can detect when sites use History API to generate the page location. Especially common with React and similar frameworks\n;(function() {\n  var pushState = history.pushState;\n  var replaceState = history.replaceState;\n\n  history.pushState = function() {\n    pushState.apply(history, arguments);\n    window.dispatchEvent(new Event(\'locationchange\'));\n  };\n\n  history.replaceState = function() {\n    replaceState.apply(history, arguments);\n    window.dispatchEvent(new Event(\'locationchange\'));\n  };\n\n  window.addEventListener(\'popstate\', function() {\n    window.dispatchEvent(new Event(\'locationchange\'))\n  });\n})();\n\nwindow.addEventListener(\'locationchange\', function(){\n  webkit.messageHandlers.locationChanged.postMessage(window.location.href)\n})""",addressHex,rpcUrl,(long)chainID];
}




+ (NSString *)javaScriptForSafaryExtension
{
    NSString *js = @"";
    NSError *error;
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"config" ofType:@"js"];
    NSString *content = [NSString stringWithContentsOfFile:filepath
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
    NSString *helpfilepath = [[NSBundle mainBundle] pathForResource:@"helpers" ofType:@"js"];
    NSString *helpcontent = [NSString stringWithContentsOfFile:helpfilepath
                                                  encoding:NSUTF8StringEncoding
                                                     error:&error];
    js = [js stringByAppendingString:content];
    js = [js stringByAppendingString:helpcontent];
    
    return js;
}

+ (NSString *)encodeStringTo64:(NSString *)fromStr
{
    NSData *plainData = [fromStr dataUsingEncoding:NSUTF8StringEncoding];
    
    return[plainData base64EncodedStringWithOptions:(NSDataBase64EncodingOptions)0];;
}

+ (void)injectJsToConfig:(WKWebViewConfiguration *)config
{
    NSString *js = [self javaScriptForSafaryExtension];
    NSString *js1 = @"""const overridenElementsForAlphaWalletExtension = new Map();function runOnStart() {function applyURLsOverriding(options, url) {let elements = overridenElementsForAlphaWalletExtension.get(url);if (typeof elements != 'undefined') {overridenElementsForAlphaWalletExtension(elements)}overridenElementsForAlphaWalletExtension.set(url, retrieveAllURLs(document, options));}const url = document.URL;applyURLsOverriding(optionsByDefault, url);}if(document.readyState !== 'loading') {runOnStart();} else {document.addEventListener('DOMContentLoaded', function() {runOnStart()});}""";
    js = [js stringByAppendingString:js1];
    
//    NSString *basestr = [self encodeStringTo64:js];
    
    NSString *jsStyle = @""" javascript:(function() {\n    var parent = document.getElementsByTagName(\'body\').item(0);\n    var script = document.createElement(\'script\');\n    script.type = \'text/javascript\';\n    script.innerHTML = window.atob(\'J3VzZSBzdHJpY3QnOwoKdmFyIG9wdGlvbnNCeURlZmF1bHQgPSB7CiAgICBlbmFibGVFaXA2ODFVcmxzT3ZlcnJpZGluZzogdHJ1ZSwKICAgIGVuYWJsZVdDVXJsc092ZXJyaWRpbmc6IHRydWUsCiAgICBhbHBoYVdhbGxldFByZWZpeDogImh0dHBzOi8vYXcuYXBwLyIsCiAgICBlbGVtZW50c0Zvck92ZXJyaWRlOiBbImEiLCAibGluayJdCn0KCmZ1bmN0aW9uIGhyZWZNYXBwZXIob3B0aW9ucykgewogICAgY29uc3QgYWxwd2FXYWxsZXRQcmVmaXggPSBvcHRpb25zLmFscGhhV2FsbGV0UHJlZml4OwogICAgbGV0IGRlZmF1bHRNYXBwZXIgPSBmdW5jdGlvbihlbGVtZW50KSB7CiAgICAgICAgcmV0dXJuIGFscHdhV2FsbGV0UHJlZml4ICsgZWxlbWVudDsKICAgIH0KCiAgICB0aGlzLmhhbmRsZXJzID0gWwogICAgICAgIHt2YWxpZGF0ZTogaXNWYWxpZEVpcDY4MSwgbWFwcGVyOiBkZWZhdWx0TWFwcGVyfSwKICAgICAgICB7dmFsaWRhdGU6IGlzVmFsaWRXYWxsZXRDb25uZWN0LCBtYXBwZXI6IGRlZmF1bHRNYXBwZXJ9CiAgICBdOwoKICAgIHRoaXMub3ZlcnJpZGVIcmVmID0gZnVuY3Rpb24oc3RyKSB7CiAgICAgICAgbGV0IGVsZW1lbnRzID0gdGhpcy5oYW5kbGVycy5tYXAoZnVuY3Rpb24oZWxlbWVudCkgewogICAgICAgICAgICBpZiAoZWxlbWVudC52YWxpZGF0ZShvcHRpb25zLCBzdHIpKSB7CiAgICAgICAgICAgICAgICByZXR1cm4gZWxlbWVudC5tYXBwZXIoc3RyKTsKICAgICAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgICAgIHJldHVybiB1bmRlZmluZWQ7CiAgICAgICAgICAgIH0KICAgICAgICB9KQogICAgICAgIC5maWx0ZXIoZWFjaCA9PiB7IHJldHVybiAoZWFjaCAhPSB1bmRlZmluZWQpIH0pOwoKICAgICAgICBpZihlbGVtZW50cy5pc0VtcHR5KSB7CiAgICAgICAgICAgIHJldHVybiB1bmRlZmluZWQ7CiAgICAgICAgfSBlbHNlIHsKICAgICAgICAgICAgcmV0dXJuIGVsZW1lbnRzWzBdOwogICAgICAgIH0KICAgIH0KfQoKZnVuY3Rpb24gaXNWYWxpZEVpcDY4MShvcHRpb25zLCBzdHIpIHsKICAgIHJldHVybiBvcHRpb25zLmVuYWJsZUVpcDY4MVVybHNPdmVycmlkaW5nICYmIHN0ci5zdGFydHNXaXRoKCJldGhlcmV1bToiKTsKfQoKZnVuY3Rpb24gaXNWYWxpZFdhbGxldENvbm5lY3Qob3B0aW9ucywgc3RyKSB7CiAgICByZXR1cm4gb3B0aW9ucy5lbmFibGVXQ1VybHNPdmVycmlkaW5nICYmIHN0ci5zdGFydHNXaXRoKCJ3YzoiKTsKfQoKZnVuY3Rpb24gcmVzdG9yZU92ZXJyaWRlblVSTHMoZWxlbWVudHMpIHsKICAgIGZvciAobGV0IGkgPSAwOyBpIDwgZWxlbWVudHMubGVuZ3RoOyBpKyspIHsKICAgICAgICBlbGVtZW50c1tpXS5lbGVtZW50LmhyZWYgPSBlbGVtZW50c1tpXS5ocmVmOwogICAgfQp9CgpmdW5jdGlvbiByZXRyaWV2ZUFsbFVSTHMoZG9jdW1lbnQsIG9wdGlvbnMpIHsKICAgIGNvbnN0IGFscHdhV2FsbGV0UHJlZml4ID0gb3B0aW9ucy5hbHBoYVdhbGxldFByZWZpeDsKICAgIGNvbnN0IG1hcHBlciA9IG5ldyBocmVmTWFwcGVyKG9wdGlvbnMpCiAgICBsZXQgdGFncyA9IG9wdGlvbnMuZWxlbWVudHNGb3JPdmVycmlkZS5tYXAoKHRhZykgPT4gewogICAgICAgIHJldHVybiBBcnJheS5mcm9tKGRvY3VtZW50LmdldEVsZW1lbnRzQnlUYWdOYW1lKHRhZykpOwogICAgfSkKICAgIC5mbGF0KCkKICAgIC5maWx0ZXIoKGVhY2gpID0+IHsgcmV0dXJuICh0eXBlb2YgZWFjaC5ocmVmICE9ICd1bmRlZmluZWQnKSB9KQoKICAgIGxldCBvdmVycmlkZW5FbGVtZW50cyA9IG5ldyBBcnJheSgpOwoKICAgIHRhZ3MuZm9yRWFjaCgoZWFjaCkgPT4gewogICAgICAgIGxldCB1cGRhdGVkSHJlZiA9IG1hcHBlci5vdmVycmlkZUhyZWYoZWFjaC5ocmVmKTsKICAgICAgICBpZiAodHlwZW9mIHVwZGF0ZWRIcmVmICE9ICd1bmRlZmluZWQnKSB7CiAgICAgICAgICAgIG92ZXJyaWRlbkVsZW1lbnRzLnB1c2goewogICAgICAgICAgICAgICAgaHJlZjogZWFjaC5ocmVmLAogICAgICAgICAgICAgICAgb3ZlcnJpZGVuSHJlZjogdXBkYXRlZEhyZWYsCiAgICAgICAgICAgICAgICBlbGVtZW50OiBlYWNoCiAgICAgICAgICAgIH0pOwoKICAgICAgICAgICAgZWFjaC5ocmVmID0gdXBkYXRlZEhyZWY7CiAgICAgICAgfQogICAgfSk7CgogICAgcmV0dXJuIG92ZXJyaWRlbkVsZW1lbnRzOwp9CiAgICAgICAgY29uc3Qgb3ZlcnJpZGVuRWxlbWVudHNGb3JBbHBoYVdhbGxldEV4dGVuc2lvbiA9IG5ldyBNYXAoKTsKICAgICAgICBmdW5jdGlvbiBydW5PblN0YXJ0KCkgewogICAgICAgICAgICBmdW5jdGlvbiBhcHBseVVSTHNPdmVycmlkaW5nKG9wdGlvbnMsIHVybCkgewogICAgICAgICAgICAgICAgbGV0IGVsZW1lbnRzID0gb3ZlcnJpZGVuRWxlbWVudHNGb3JBbHBoYVdhbGxldEV4dGVuc2lvbi5nZXQodXJsKTsKICAgICAgICAgICAgICAgIGlmICh0eXBlb2YgZWxlbWVudHMgIT0gJ3VuZGVmaW5lZCcpIHsKICAgICAgICAgICAgICAgICAgICBvdmVycmlkZW5FbGVtZW50c0ZvckFscGhhV2FsbGV0RXh0ZW5zaW9uKGVsZW1lbnRzKQogICAgICAgICAgICAgICAgfQoKICAgICAgICAgICAgICAgIG92ZXJyaWRlbkVsZW1lbnRzRm9yQWxwaGFXYWxsZXRFeHRlbnNpb24uc2V0KHVybCwgcmV0cmlldmVBbGxVUkxzKGRvY3VtZW50LCBvcHRpb25zKSk7CiAgICAgICAgICAgIH0KCiAgICAgICAgICAgIGNvbnN0IHVybCA9IGRvY3VtZW50LlVSTDsKICAgICAgICAgICAgYXBwbHlVUkxzT3ZlcnJpZGluZyhvcHRpb25zQnlEZWZhdWx0LCB1cmwpOwogICAgICAgIH0KCiAgICAgICAgaWYoZG9jdW1lbnQucmVhZHlTdGF0ZSAhPT0gJ2xvYWRpbmcnKSB7CiAgICAgICAgICAgIHJ1bk9uU3RhcnQoKTsKICAgICAgICB9IGVsc2UgewogICAgICAgICAgICBkb2N1bWVudC5hZGRFdmVudExpc3RlbmVyKCdET01Db250ZW50TG9hZGVkJywgZnVuY3Rpb24oKSB7CiAgICAgICAgICAgICAgICBydW5PblN0YXJ0KCkKICAgICAgICAgICAgfSk7CiAgICAgICAgfQ==\');\n    parent.appendChild(script)})()""";
    
    WKUserScript *userScript = [[WKUserScript alloc] initWithSource:jsStyle
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentEnd
                                                   forMainFrameOnly:true];
    [config.userContentController addUserScript:userScript];
    
    
}



@end
