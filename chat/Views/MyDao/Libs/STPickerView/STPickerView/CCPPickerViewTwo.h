//
//  CCPPickerViewTwo.h
//  CCPPickerView
//
//  Created by CCP on 16/7/7.
//  Copyright © 2016年 CCP. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^clickCancelBtn)(void);

typedef void(^clickSureBtn)(NSString *leftString,NSString *rightString,NSString *leftAndRightString);

@interface CCPPickerViewTwo : UIView

@property (nonatomic, copy) NSString *stime;
@property (nonatomic, copy) NSString *etime;
@property (copy,nonatomic) void(^clickCancelBtn)(void);
@property (copy,nonatomic) void (^clickSureBtn)(NSString *leftString,NSString *rightString,NSString *leftAndRightString);

- (instancetype)initWithpickerViewWithCenterTitle:(NSString *)title andCancel:(NSString *)cancel andSure:(NSString *)sure andDataArray:(NSMutableArray *)array;
- (instancetype)initWithpickerViewWithDataArray:(NSMutableArray *)array stime:(NSString *)stime etime:(NSString *)etime;
- (void)pickerVIewClickCancelBtnBlock:(clickCancelBtn)cancelBlock
                          sureBtClcik:(clickSureBtn)sureBlock;

@end
