//
//  PWTransferNoteView.h
//  PWallet
//
//  Created by 于优 on 2018/11/16.
//  Copyright © 2018 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PWTransferNoteView : UIView

/*备注TextField**/
@property (nonatomic, strong) UITextField *noteText;
@property (nonatomic, strong) UITextView *noteTextView;
@property (nonatomic, copy) NSString *titleStr;

/** 查看解释 */
@property (nonatomic, copy) void(^didExplainMessageHandle)(void);

- (void)setKeybordBtn:(UIButton *)keybordBtn action:(SEL) action;

@end
