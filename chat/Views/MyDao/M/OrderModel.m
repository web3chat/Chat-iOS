//
//  OrderModel.m
//  PWallet
//
//  Created by 宋刚 on 2018/6/20.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import "OrderModel.h"

@implementation OrderModel
- (instancetype)initWithDic:(NSDictionary *)dic
{
    self = [super init];
    if (self) {
        NSInteger status = [dic[@"status"] integerValue];
        if (status == 0) {
            self.state = TransferFromStatusEnsureing;
        }else if (status == 1)
        {
            self.state = TransferFromStatusSuccess;
        }else if (status == -1)
        {
            self.state = TransferFromStatusFailure;
        }
        self.coinNum = [dic[@"value"] doubleValue];
        self.time = dic[@"blocktime"];
        self.blockHeight = dic[@"height"];
        self.blockHash = dic[@"txid"];
        self.note = dic[@"note"];
        self.fee = [dic[@"fee"] doubleValue];
        self.toAddress = dic[@"to"];
        self.fromAddress = dic[@"from"];
        self.type = [NSString stringWithFormat:@"%@",dic[@"type"]];
        if (dic[@"category"] != nil) {
            self.category = dic[@"category"];
        }else{
            self.category = @"";
        }
        self.category_name = dic[@"category_name"];

    }
    return self;
}
@end
