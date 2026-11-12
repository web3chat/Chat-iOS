#import "Web3ProviderHandler.h"

@interface Web3ProviderHandler ()
@property (nonatomic, strong, readwrite) NSOperationQueue *requestQueue;
@property (nonatomic, strong) NSURLSession *urlSession;
@end

@implementation Web3ProviderHandler

- (instancetype)init {
    self = [super init];
    if (self) {
        _requestQueue = [[NSOperationQueue alloc] init];
        _requestQueue.name = @"com.benefy.wallet.web3.rpc";
        _requestQueue.maxConcurrentOperationCount = 8;
    }
    return self;
}

- (NSURLSession *)urlSession {
    @synchronized (self) {
        if (!_urlSession) {
            NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
            cfg.timeoutIntervalForRequest = 60.0;
            cfg.timeoutIntervalForResource = 180.0;
            cfg.waitsForConnectivity = YES;
            cfg.HTTPMaximumConnectionsPerHost = 8;
            _urlSession = [NSURLSession sessionWithConfiguration:cfg delegate:nil delegateQueue:nil];
        }
    }
    return _urlSession;
}

- (void)enqueueJsonRpcPostWithURL:(NSString *)rpcURLString
                    jsonRpcBody:(NSDictionary *)jsonRpcBody
                    httpHeaders:(NSDictionary<NSString *, NSString *> *)httpHeaders
                     completion:(void (^)(NSDictionary *_Nullable, NSError *_Nullable))completion {
    NSDictionary *bodyCopy = [jsonRpcBody copy];
    NSDictionary *headersCopy = [httpHeaders copy];
    NSString *urlCopy = [rpcURLString copy];
    [self.requestQueue addOperationWithBlock:^{
        void (^finish)(NSDictionary *_Nullable, NSError *_Nullable) = completion;

        NSURL *url = [NSURL URLWithString:urlCopy];
        if (!url) {
            NSError *e = [NSError errorWithDomain:@"Web3ProviderHandler" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"invalid RPC URL"}];
            if (finish) {
                finish(nil, e);
            }
            return;
        }

        NSError *jsonErr = nil;
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:bodyCopy options:0 error:&jsonErr];
        if (!bodyData) {
            if (finish) {
                finish(nil, jsonErr ?: [NSError errorWithDomain:@"Web3ProviderHandler" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"JSON encode failed"}]);
            }
            return;
        }

        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
        req.HTTPMethod = @"POST";
        req.HTTPBody = bodyData;
        [headersCopy enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
            [req setValue:obj forHTTPHeaderField:key];
        }];

        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        __block NSData *respData = nil;
        __block NSError *taskErr = nil;
        NSURLSessionDataTask *task = [[self urlSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            respData = data;
            taskErr = error;
            if (!taskErr && [response isKindOfClass:[NSHTTPURLResponse class]]) {
                NSInteger code = [(NSHTTPURLResponse *)response statusCode];
                if (code < 200 || code >= 300) {
                    NSString *msg = [NSString stringWithFormat:@"RPC HTTP %ld", (long)code];
                    taskErr = [NSError errorWithDomain:@"Web3ProviderHandler" code:(NSInteger)code userInfo:@{NSLocalizedDescriptionKey: msg}];
                }
            }
            dispatch_semaphore_signal(sem);
        }];
        [task resume];
        dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

        if (taskErr) {
            if (finish) {
                finish(nil, taskErr);
            }
            return;
        }
        if (!respData.length) {
            NSError *e = [NSError errorWithDomain:@"Web3ProviderHandler" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"empty RPC response"}];
            if (finish) {
                finish(nil, e);
            }
            return;
        }

        NSError *parseErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:respData options:NSJSONReadingMutableLeaves error:&parseErr];
        if (!json) {
            if (finish) {
                finish(nil, parseErr);
            }
            return;
        }
        if (finish) {
            finish(json, nil);
        }
    }];
}

@end
