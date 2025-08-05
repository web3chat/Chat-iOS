//
//  PWNFTRequest.m
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2022/5/18.
//

#import "PWNFTRequest.h"
#import "Depend.h"
#import "chat-Swift.h"
#define kSLGNFTTOKENSYMBOL @"testproofv2.token"

@implementation PWNFTRequest



+ (void)requestNFTBalanceWithCoinType:(NSString *)coinType from:(NSString *)from contractAddr:(NSString *)contractAddr success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"from":from,@"contractAddr":contractAddr};
    NSDictionary *rawdata = @{@"method":@"NFT_BalanceOf",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:SLGNFTURL
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

+ (void)requestNFTOwnerAddrWithCoinType:(NSString *)coinType tokenId:(NSString *)tokendId contractAddr:(NSString *)contractAddr success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"tokenId":tokendId,@"contractAddr":contractAddr};
    NSDictionary *rawdata = @{@"method":@"NFT_OwnerOf",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:chain
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

+ (void)requestNFTTokenIdListWithCoinType:(NSString *)coinType from:(NSString *)from contractAddr:(NSString *)contractAddr success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"from":from,@"contractAddr":contractAddr};
    NSDictionary *rawdata = @{@"method":@"NFT_TokenIdList",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata};
    NSDictionary *param = @{@"jsonrpc":@"2",@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:chain
                                          apiPath:@""
                                       parameters:param
                                         progress:nil
                                          success:^(BOOL isSuccess, id  _Nullable responseObject) {
        if (successBlock) {
            successBlock(responseObject);
        }
    } failure:^(NSString * _Nullable errorMessage) {

    }];
    
}

+ (void)requestNFTTokenURLWithCoinType:(NSString *)coinType tokenId:(NSString *)tokendId contractAddr:(NSString *)contractAddr success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"tokenId":tokendId,@"contractAddr":contractAddr};
    NSDictionary *rawdata = @{@"method":@"NFT_TokenURI",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:chain
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

+ (void)approveNFTWithCoinType:(NSString *)coinType tokenId:(NSString *)tokendId contractAddr:(NSString *)contractAddr from:(NSString *)from to:(NSString *)to fee:(CGFloat)fee success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"tokenId":tokendId,@"contractAddr":contractAddr,@"to":to, @"from":from, @"fee":[NSNumber numberWithFloat:fee]};
    NSDictionary *rawdata = @{@"method":@"NFT_Approve",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:chain
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


+ (void)requestApproveAddrWithCoinType:(NSString *)coinType tokenId:(NSString *)tokendId contractAddr:(NSString *)contractAddr success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"tokenId":tokendId,@"contractAddr":contractAddr};
    NSDictionary *rawdata = @{@"method":@"NFT_GetApproved",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:chain
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

+ (void)requestApproveForAllWithCoinType:(NSString *)coinType from:(NSString *)from to:(NSString *)to contractAddr:(NSString *)contractAddr success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"from":from,@"to":to,@"contractAddr":contractAddr};
    NSDictionary *rawdata = @{@"method":@"NFT_IsApprovedForAll",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:chain
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

+ (void)setApproveForAllNFTwITHCoinType:(NSString *)coinType from:(NSString *)from to:(NSString *)to contractAddr:(NSString *)contractAddr approve:(BOOL)approve fee:(CGFloat)fee success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"from":from,@"to":to,@"contractAddr":contractAddr,@"approved":[NSNumber numberWithBool:approve],@"fee":[NSNumber numberWithFloat:fee]};
    NSDictionary *rawdata = @{@"method":@"NFT_SetApprovalForAll",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:chain
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

+ (void)nftTransferWithoinType:(NSString *)coinType from:(NSString *)from to:(NSString *)to contractAddr:(NSString *)contractAddr tokenId:(NSString *)tokenId fee:(CGFloat)fee success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"from":from,@"to":to,@"contractAddr":contractAddr,@"tokenId":tokenId,@"fee":[NSNumber numberWithFloat:fee]};
    NSDictionary *rawdata = @{@"method":@"NFT_TransferFrom",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:chain
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

+ (void)requestTxsByAddrWithCoinType:(NSString *)coinType address:(NSString *)address contractAddr:(NSString *)contractAddr index:(NSInteger)index count:(NSInteger)count direction:(NSInteger)direction type:(NSInteger)type success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"address":address,
                              @"contractAddr":contractAddr,
                              @"index":[NSNumber numberWithInteger:index],
                              @"count":[NSNumber numberWithInteger:count],
                              @"direction":[NSNumber numberWithInteger:direction],
                              @"type":[NSNumber numberWithInteger:type]};
    NSDictionary *rawdata = @{@"method":@"NFT_QueryTxsByAddr",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    BlockchainTool *tool = [[BlockchainTool alloc] init];
    NSString *chain = [tool getBlockChain];
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:chain
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

+ (void)requestERC721NFTBalanceWith:(NSString *)coinType nftType:(NSString *)nftType contractAddr:(NSString *)contractAddr fromAddr:(NSString *)formAddr success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"nftType":nftType,
                              @"contractAddr":contractAddr,
                              @"from":formAddr};
    NSDictionary *rawdata = @{@"method":@"NFT_BalanceOf",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata,@"tokenSymbol":kSLGNFTTOKENSYMBOL};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
   
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:SLGNFTURL
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

+ (void)requestERC1155NFTBalanceWith:(NSString *)coinType nftType:(NSString *)nftType tokenId:(NSString *)tokenId contractAddr:(NSString *)contractAddr fromAddr:(NSString *)formAddr success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"nftType":nftType,
                              @"tokenId":tokenId,
                              @"contractAddr":contractAddr,
                              @"from":formAddr};
    NSDictionary *rawdata = @{@"method":@"NFT_BalanceOf",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata,@"tokenSymbol":kSLGNFTTOKENSYMBOL};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:SLGNFTURL
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

+ (void)transSLGNFTWithCoinType:(NSString *)coinType nftType:(NSString *)nftType tokenId:(NSString *)tokenId contractAddr:(NSString *)contractAddr fromAddr:(NSString *)formAddr toAddr:(NSString *)toAddr amount:(NSInteger)amount fee:(CGFloat)fee success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"nftType":nftType,
                              @"tokenId":tokenId,
                              @"contractAddr":contractAddr,
                              @"from":formAddr,
                              @"to":toAddr,
                              @"amount":[NSNumber numberWithInteger:amount],
                              @"fee":[NSNumber numberWithFloat:fee]};
    NSDictionary *rawdata = @{@"method":@"NFT_TransferToken",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata,@"tokenSymbol":kSLGNFTTOKENSYMBOL};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:SLGNFTURL
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


+ (void)requstSLGTxsByCoinType:(NSString *)coinType address:(NSString *)address contractAddr:(NSString *)contractAddr index:(NSInteger)index count:(NSInteger)count direction:(NSInteger)direction type:(NSInteger)type success:(requestSuccessBlock)successBlock failure:(requestFailuresBlock)failureBlock
{
    if (contractAddr == nil) {
        return;
    }
    NSDictionary *payload = @{@"address":address,
                              @"contractAddr":contractAddr,
                              @"index":[NSNumber numberWithInteger:index],
                              @"count":[NSNumber numberWithInteger:count],
                              @"direction":[NSNumber numberWithInteger:direction],
                              @"type":[NSNumber numberWithInteger:type]};
    NSDictionary *rawdata = @{@"method":@"NFT_QueryTxsByAddr",@"payload":payload};
    NSDictionary *params = @{@"cointype":coinType,@"rawdata":rawdata,@"tokenSymbol":kSLGNFTTOKENSYMBOL};
    NSDictionary *param = @{@"id":@1,@"method":@"Wallet.Transport",@"params":@[params]};
    
    [[SGNetWork defaultManager] sendRequestMethod:HTTPMethodPOST
                                        serverUrl:SLGNFTURL
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
