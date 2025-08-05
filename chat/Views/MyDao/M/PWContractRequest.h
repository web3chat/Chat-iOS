//
//  PWContractRequest.h
//  chat
//
//  Created by 郑晨 on 2025/4/18.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
//网络请求成功回调block
typedef void (^requestSuccessBlock)(id object);
//网络请求失败回调block
typedef void (^requestFailuresBlock)(NSString *errorMsg);

@interface PWContractRequest : NSObject


/// 查询合约信息
/// - Parameters:
///   - coinType: 主链
///   - address: 地址，填空
///   - execer: 合约地址
///   - successBlock: 成功回调
///   - failureBlock: 失败回调
+(void)getContractorInfowithCoinType:(NSString *)coinType
                             address:(NSString *)address
                              execer:(NSString *)execer
                             success:(requestSuccessBlock)successBlock
                             failure:(requestFailuresBlock)failureBlock;


/// 根据合约地址构造交易
/// - Parameters:
///   - coinType: 主链
///   - tokensymbol: tokensymbol
///   - fromAddr: 发送地址
///   - toAddr: 接收地址
///   - amount: 金额
///   - fee: 手续费
///   - tokenAddr: 合约地址
///   - successBlock: 成功回调
///   - failureBlock: 失败回调
+(void)createRawTranscationWithCoinType:(NSString *)coinType
                            tokensymbol:(NSString *)tokensymbol
                                 fromAddr:(NSString *)fromAddr
                                 toAddr:(NSString *)toAddr
                                 amount:(double )amount
                                    fee:(double )fee
                              tokenAddr:(NSString *)tokenAddr
                                success:(requestSuccessBlock)successBlock
                                failure:(requestFailuresBlock)failureBlock;


/// 根据合约地址差余额
/// - Parameters:
///   - coinType: 主链
///   - address: 地址
///   - execer: 合约地址
///   - successBlock: 成功回调
///   - failureBlock: 失败回调
+(void)getBalancewithCoinType:(NSString *)coinType
                             address:(NSString *)address
                              execer:(NSString *)execer
                             success:(requestSuccessBlock)successBlock
                             failure:(requestFailuresBlock)failureBlock;

/// 查询合约地址交易记录
/// - Parameters:
///   - address: 地址
///   - coinType: 主链
///   - contractAddr: 合约地址
///   - index: 索引
///   - count: 数量
///   - direction: 方向
///   - type: 类型
///   - successBlock: 成功回调
///   - failureBlock: 失败回调
+ (void)queryTransactionByAddress:(NSString *)address
                         coinType:(NSString *)coinType
                     contractAddr:(NSString *)contractAddr
                            index:(NSInteger)index
                            count:(NSInteger)count
                        direction:(NSInteger)direction
                             type:(NSInteger)type
                          success:(requestSuccessBlock)successBlock
                          failure:(requestFailuresBlock)failureBlock;




/// 签名
/// - Parameters:
///   - from: 转币地址
///   - to: 转出地址
///   - amount: 金额
///   - fee: 矿工费
///   - coinType: 主链
///   - tokenSymbol: tokensymbol
///   - tokenAddr: 合约地址
///   - successBlock: 成功回调
///   - failureBlock: 失败回调
+ (void)signwwrwaDataWithForm:(NSString *)from
                           to:(NSString *)to
                       amount:(double)amount
                          fee:(double)fee
                     coinType:(NSString *)coinType
                  tokenSymbol:(NSString *)tokenSymbol
                    tokenAddr:(NSString *)tokenAddr
                      success:(requestSuccessBlock)successBlock
                      failure:(requestFailuresBlock)failureBlock;


/// 根据交易hash获取交易记录详情
/// - Parameters:
///   - txid: 交易hash
///   - coinType: 币种主链
///   - tokenSymbol: tokensymbol
///   - successBlock: 成功回调
///   - failureBlock: 失败回调
+ (void)queryTranscationByTxid:(NSString *)txid
                      coinType:(NSString *)coinType
                   tokenSymbol:(NSString *)tokenSymbol
                       success:(requestSuccessBlock)successBlock
                       failure:(requestFailuresBlock)failureBlock;


@end

NS_ASSUME_NONNULL_END
