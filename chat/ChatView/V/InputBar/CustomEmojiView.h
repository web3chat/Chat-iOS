//
//  CustomEmojiView.h
//  chat
//
//  Created by liyaqin on 2021/9/14.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol CustomEmojiDelegate <NSObject>

@optional

- (void)didClickEmojiLabel:(NSString *)emojiStr;

- (void)didClickSendEmojiBtn;

- (void)didDeleteEmojiBtn;
@end

@interface CustomEmojiView : UIView
@property (nonatomic, weak) id<CustomEmojiDelegate> delegate;
@end

NS_ASSUME_NONNULL_END
