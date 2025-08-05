//
//  ContactView.h
//  chat
//
//  Created by 郑晨 on 2025/3/4.
//

#import <UIKit/UIKit.h>
#import "chat-Swift.h"

NS_ASSUME_NONNULL_BEGIN


typedef void(^ContactViewBlock)(NSString * _Nullable  str);
typedef void(^CoSelectedFBlock)();
@interface ContactView : UIView

@property (nonatomic, strong) NSDictionary *contactDict;
@property (nonatomic, strong) LocalCoin *coin;

@property (nonatomic) ContactViewBlock contactViewBlock;
@property (nonatomic) CoSelectedFBlock coSelectedFBlock;
@end

NS_ASSUME_NONNULL_END
