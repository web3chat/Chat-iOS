#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Web3 JSON-RPC 任务池：并发受控，避免打爆 RPC；单次请求在 operation 内用信号量等待 HTTP 结束，保证并发数与 maxConcurrentOperationCount 一致。
@interface Web3ProviderHandler : NSObject

@property (nonatomic, strong, readonly) NSOperationQueue *requestQueue;

/// 在 requestQueue 上排队执行；completion 在后台队列回调（由调用方再派主线程）。
- (void)enqueueJsonRpcPostWithURL:(NSString *)rpcURLString
                    jsonRpcBody:(NSDictionary *)jsonRpcBody
                    httpHeaders:(NSDictionary<NSString *, NSString *> *)httpHeaders
                     completion:(void (^)(NSDictionary *_Nullable json, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
