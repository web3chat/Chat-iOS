//
//  PWNFTRequest.h
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2022/5/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

//网络请求成功回调block
typedef void (^requestSuccessBlock)(id object);
//网络请求失败回调block
typedef void (^requestFailuresBlock)(NSString *errorMsg);

@interface PWNFTRequest : NSObject

/// 查询NFT合约地址下的所有NFT余额
/// @param coinType NFT 主链
/// @param from NFT地址
/// @param contractAddr NFT 合约地址
/// @param successBlock 成功回调
/// @param failureBlock 失败回调
+ (void)requestNFTBalanceWithCoinType:(NSString *)coinType
                                 from:(NSString *)from
                         contractAddr:(NSString *)contractAddr
                              success:(requestSuccessBlock)successBlock
                              failure:(requestFailuresBlock)failureBlock;


/// 查询指定NFT的拥有者的地址
/// @param coinType  NFT 主链
/// @param tokendId NFT ID
/// @param contractAddr NFT 合约地址
/// @param successBlock 成功回调
/// @param failureBlock 失败回调
+ (void)requestNFTOwnerAddrWithCoinType:(NSString *)coinType
                                tokenId:(NSString *)tokendId
                           contractAddr:(NSString *)contractAddr
                                success:(requestSuccessBlock)successBlock
                                failure:(requestFailuresBlock)failureBlock;


/// 查询用户的NFT列表
/// @param coinType  NFT 主链
/// @param from NFT地址
/// @param contractAddr NFT 合约地址
/// @param successBlock 成功回调
/// @param failureBlock  失败回调
+ (void)requestNFTTokenIdListWithCoinType:(NSString *)coinType
                                     from:(NSString *)from
                             contractAddr:(NSString *)contractAddr
                                  success:(requestSuccessBlock)successBlock
                                  failure:(requestFailuresBlock)failureBlock;




/// 查询指定ID的NFT 的URI
/// @param coinType  NFT 主链
/// @param tokendId NFT ID
/// @param contractAddr NFT 合约地址
/// @param successBlock 成功回调
/// @param failureBlock 失败回调
+ (void)requestNFTTokenURLWithCoinType:(NSString *)coinType
                               tokenId:(NSString *)tokendId
                          contractAddr:(NSString *)contractAddr
                               success:(requestSuccessBlock)successBlock
                               failure:(requestFailuresBlock)failureBlock;



/// 将用户NFT合约地址上指定的NFT授权给其他地址管理
/// @param coinType  NFT 主链
/// @param tokendId NFT ID
/// @param contractAddr NFT 合约地址
/// @param from 用户NFT地址
/// @param to 被授权地址
/// @param fee 手续费
/// @param successBlock 成功回调
/// @param failureBlock  失败回调
+ (void)approveNFTWithCoinType:(NSString *)coinType
                       tokenId:(NSString *)tokendId
                  contractAddr:(NSString *)contractAddr
                          from:(NSString *)from
                            to:(NSString *)to
                           fee:(CGFloat)fee
                       success:(requestSuccessBlock)successBlock
                       failure:(requestFailuresBlock)failureBlock;


/// 查询指定ID的NFT被授权的地址
/// @param coinType  NFT 主链
/// @param tokendId NFT ID
/// @param contractAddr NFT 合约地址
/// @param successBlock 成功回调
/// @param failureBlock 失败回调
+(void)requestApproveAddrWithCoinType:(NSString *)coinType
                              tokenId:(NSString *)tokendId
                         contractAddr:(NSString *)contractAddr
                              success:(requestSuccessBlock)successBlock
                              failure:(requestFailuresBlock)failureBlock;


/// 查询用户是否已授权指定地址操作NFT合约地址上所有资产
/// @param coinType  NFT 主链
/// @param from 用户NFT地址
/// @param to 被授权地址
/// @param contractAddr NFT 合约地址
/// @param successBlock 成功回调
/// @param failureBlock 失败回调
+ (void)requestApproveForAllWithCoinType:(NSString *)coinType
                                    from:(NSString *)from
                                    to:(NSString *)to
                            contractAddr:(NSString *)contractAddr
                                 success:(requestSuccessBlock)successBlock
                                 failure:(requestFailuresBlock)failureBlock;


/// 将用户NFT合约地址上所有NFT资产授权给其他地址管理
/// @param coinType NFT 主链
/// @param from 用户NFT地址
/// @param to 被授权地址
/// @param contractAddr  NFT 合约地址
/// @param approve  true 授权 false 取消授权
/// @param fee 手续费
/// @param successBlock 成功回调
/// @param failureBlock 失败回调
+ (void)setApproveForAllNFTwITHCoinType:(NSString *)coinType
                                   from:(NSString *)from
                                     to:(NSString *)to
                           contractAddr:(NSString *)contractAddr
                                approve:(BOOL)approve
                                    fee:(CGFloat)fee
                                success:(requestSuccessBlock)successBlock
                                failure:(requestFailuresBlock)failureBlock;


/// NFT转账, 将指定的NFT从from地址转移给to地址
/// @param coinType  NFT 主链
/// @param from 用户NFT地址
/// @param to 接收地址
/// @param contractAddr NFT 合约地址
/// @param tokenId NFT ID
/// @param fee 手续费
/// @param successBlock 成功回调
/// @param failureBlock 失败回调
+ (void)nftTransferWithoinType:(NSString *)coinType
                          from:(NSString *)from
                            to:(NSString *)to
                  contractAddr:(NSString *)contractAddr
                       tokenId:(NSString *)tokenId
                           fee:(CGFloat)fee
                       success:(requestSuccessBlock)successBlock
                       failure:(requestFailuresBlock)failureBlock;


/// NFT转账账单查询
/// @param coinType   NFT 主链
/// @param address 用户NFT地址
/// @param contractAddr NFT 合约地址
/// @param index 偏移量  从0开始
/// @param count 每页显示条数
/// @param direction int 0根据时间降序 1-根据时间升序
/// @param type 1-查询转出记录 2-查询转入记录 0-查询全部记录
/// @param successBlock 成功回调
/// @param failureBlock 失败回调
+ (void)requestTxsByAddrWithCoinType:(NSString *)coinType
                             address:(NSString *)address
                        contractAddr:(NSString *)contractAddr
                               index:(NSInteger )index
                               count:(NSInteger)count
                           direction:(NSInteger)direction
                                type:(NSInteger)type
                             success:(requestSuccessBlock)successBlock
                             failure:(requestFailuresBlock)failureBlock;


#pragma mark -- 上链购NFT

/// 查询ERC721 NFT余额
/// @param coinType NFT 主链
/// @param nftType  NFT 类型 (ERC721) 如果不填默认是ERC721
/// @param contractAddr ERC721 NFT合约地址
/// @param formAddr 用户地址
/// @param successBlock 成功回调
/// @param failureBlock 失败回调
+ (void)requestERC721NFTBalanceWith:(NSString *)coinType
                            nftType:(NSString *)nftType
                       contractAddr:(NSString *)contractAddr
                           fromAddr:(NSString *)formAddr
                            success:(requestSuccessBlock)successBlock
                            failure:(requestFailuresBlock)failureBlock;


/// 查询ERC1155 NFT余额
/// @param coinType NFT 主链
/// @param nftType  NFT 类型 (ERC1155) 如果不填默认是ERC721
/// @param tokenId NFT Tokenid
/// @param contractAddr ERC1155 NFT合约地址
/// @param formAddr 用户地址
/// @param successBlock 成功回调
/// @param failureBlock 失败回调
+ (void)requestERC1155NFTBalanceWith:(NSString *)coinType
                            nftType:(NSString *)nftType
                            tokenId:(NSString *)tokenId
                       contractAddr:(NSString *)contractAddr
                           fromAddr:(NSString *)formAddr
                            success:(requestSuccessBlock)successBlock
                            failure:(requestFailuresBlock)failureBlock;



/// 构造上链购 NFT转账交易
/// @param coinType NFT 主链
/// @param nftType  NFT 类型 (ERC1155或ERC721)
/// @param tokenId NFT Tokenid
/// @param contractAddr  NFT合约地址
/// @param formAddr 发送地址
/// @param toAddr 接收地址
/// @param amount 金额 （ERC721 NFT 金额默认是1）
/// @param fee 手续费
/// @param successBlock 成功回调
/// @param failureBlock 失败回调
+ (void)transSLGNFTWithCoinType:(NSString *)coinType
                        nftType:(NSString *)nftType
                        tokenId:(NSString *)tokenId
                   contractAddr:(NSString *)contractAddr
                       fromAddr:(NSString *)formAddr
                         toAddr:(NSString *)toAddr
                         amount:(NSInteger)amount
                            fee:(CGFloat)fee
                        success:(requestSuccessBlock)successBlock
                        failure:(requestFailuresBlock)failureBlock;


/// 上链购NFT转账账单查询
/// @param coinType   NFT 主链
/// @param address 用户NFT地址
/// @param contractAddr NFT 合约地址
/// @param index 偏移量  从0开始
/// @param count 每页显示条数
/// @param direction int 0根据时间降序 1-根据时间升序
/// @param type 1-查询转出记录 2-查询转入记录 0-查询全部记录
/// @param successBlock 成功回调
/// @param failureBlock 失败回调
+ (void)requstSLGTxsByCoinType:(NSString *)coinType
                       address:(NSString *)address
                  contractAddr:(NSString *)contractAddr
                         index:(NSInteger )index
                         count:(NSInteger)count
                     direction:(NSInteger)direction
                          type:(NSInteger)type
                       success:(requestSuccessBlock)successBlock
                       failure:(requestFailuresBlock)failureBlock;


@end

NS_ASSUME_NONNULL_END
