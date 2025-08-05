//
//  PWContractRequest.m
//  chat
//
//  Created by 郑晨 on 2025/4/18.
//

#import "PWContractRequest.h"
#import "Depend.h"

static NSString *gonodeurl = GoNodeUrl;  //@"https://190.92.231.38:58083";

@implementation PWContractRequest

+ (void)getContractorInfowithCoinType:(NSString *)coinType address:(NSString *)address execer:(NSString *)execer success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    NSDictionary *execerInfo = @{@"Execer":execer};
    NSDictionary *params = @{@"cointype":coinType,
                             @"address":address,
                             @"extend_info":execerInfo};
    NSDictionary *param = @{@"id":@1,
                            @"jsonrpc":@"2.0",
                            @"method":@"Wallet.GetContractorInfo",
                            @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
    
}

+ (void)createRawTranscationWithCoinType:(NSString *)coinType tokensymbol:(NSString *)tokensymbol fromAddr:(NSString *)fromAddr toAddr:(NSString *)toAddr amount:(double)amount fee:(double)fee tokenAddr:(NSString *)tokenAddr success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    NSDictionary *tokenAddrs = @{@"token_addr":tokenAddr};
    NSDictionary *transaction = @{@"from":fromAddr,
                                  @"to":toAddr,
                                  @"amount":@(amount),
                                  @"fee":@(fee),
                                  @"extend":tokenAddrs};
    NSDictionary *params = @{@"cointype":coinType,
                             @"tokensymbol":tokensymbol,
                             @"transaction":transaction};
    NSDictionary *param = @{@"id":@0,
                            @"jsonrpc":@"2.0",
                            @"method":@"Wallet.CreateRawTransaction",
                            @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
}

+ (void)getBalancewithCoinType:(NSString *)coinType address:(NSString *)address execer:(NSString *)execer success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    NSDictionary *execerInfo = @{@"Execer":execer};
    NSDictionary *params = @{@"cointype":coinType,
                             @"address":address,
                             @"extend_info":execerInfo};
    NSDictionary *param = @{@"id":@1,
                            @"jsonrpc":@"2.0",
                            @"method":@"Wallet.GetBalance",
                            @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
}

+ (void)queryTransactionByAddress:(NSString *)address coinType:(NSString *)coinType contractAddr:(NSString *)contractAddr index:(NSInteger)index count:(NSInteger)count direction:(NSInteger)direction type:(NSInteger)type success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
 
    NSDictionary *params = @{@"cointype":coinType,
                             @"address":address,
                             @"contractAddr":contractAddr,
                             @"index":@(index),
                             @"count":@(count),
                             @"direction":@(direction),
                             @"type":@(type)};
    NSDictionary *param =  @{@"id":@1,
                             @"jsonrpc":@"2.0",
                             @"method":@"Wallet.QueryTransactionsByaddress",
                             @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
}

+ (void)signwwrwaDataWithForm:(NSString *)from to:(NSString *)to amount:(double)amount fee:(double)fee coinType:(NSString *)coinType tokenSymbol:(NSString *)tokenSymbol tokenAddr:(NSString *)tokenAddr success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    NSDictionary *extend = @{@"token_addr":tokenAddr};
    NSDictionary *transcation = @{@"from":from,
                                  @"to":to,
                                  @"amount":@(amount),
                                  @"fee":@(fee),
                                  @"extend":extend};
    NSDictionary *params = @{@"cointype":coinType,
                             @"tokensymbol":@"",
                             @"transaction":transcation};
    NSDictionary *param = @{@"id":@1,
                            @"method":@"Wallet.CreateRawTransaction",
                            @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
}


+ (void)queryTranscationByTxid:(NSString *)txid coinType:(NSString *)coinType tokenSymbol:(NSString *)tokenSymbol success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    NSDictionary *params = @{@"cointype":coinType,
                             @"tokensymbol":tokenSymbol,
                             @"txid":txid};
    NSDictionary *param = @{@"id":@1,
                            @"method":@"Wallet.QueryTransactionByTxid",
                            @"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:gonodeurl
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {
        if (failureBlock) {
            failureBlock(errorMessage);
        }
    }];
    
}

@end
