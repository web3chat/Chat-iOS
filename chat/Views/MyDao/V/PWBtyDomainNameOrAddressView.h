//
//  PWBtyDomainNameOrAddressView.h
//  PWalletInterfaceSDk
//
//  Created by 郑晨 on 2022/8/11.
//  Copyright © 2022 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^DomainNameOrAddressChoiceBlock)(NSString *str);

@interface PWBtyDomainNameOrAddressView : UIView

- (instancetype)initWithData:(NSArray *)dataArray;

@property (nonatomic) DomainNameOrAddressChoiceBlock domainNameOrAddressChoiceBlock;

@end

NS_ASSUME_NONNULL_END
