//
//  PWReloadView.h
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^ReloadBlock)(void);

@interface PWReloadView : UIView

@property (nonatomic) ReloadBlock reloadBlock; // 重新加载

- (instancetype)initWithFrame:(CGRect)frame withError:(NSError *)error;



@end

NS_ASSUME_NONNULL_END
