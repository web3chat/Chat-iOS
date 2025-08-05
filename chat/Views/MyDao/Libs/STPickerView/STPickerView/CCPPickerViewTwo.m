//
//  CCPPickerViewTwo.m
//  CCPPickerView
//
//  Created by CCP on 16/7/7.
//  Copyright © 2016年 CCP. All rights reserved.
//

#import "CCPPickerViewTwo.h"
#import "Depend.h"

#define CCPWIDTH [UIScreen mainScreen].bounds.size.width
#define CCPHEIGHT [UIScreen mainScreen].bounds.size.height

@interface CCPPickerViewTwo ()<UIPickerViewDataSource,UIPickerViewDelegate>

@property (strong, nonatomic) NSMutableArray *dateArray;
@property (nonatomic,strong)UIPickerView *pickerViewLoanLine;
@property (nonatomic,strong)UIToolbar *toolBarTwo;
//组合view
@property (nonatomic,strong) UIView *containerView;

@property (copy, nonatomic) NSString *string1;
@property (copy, nonatomic) NSString *string2;
@property (assign, nonatomic)NSInteger index1;
@property (assign, nonatomic)NSInteger index2;

@property (copy,nonatomic)NSString *titleString;
@property (copy,nonatomic)NSString *leftString;
@property (copy,nonatomic)NSString *rightString;




@end


@implementation CCPPickerViewTwo


- (UIPickerView *)pickerViewLoanLine {
    
    if (_pickerViewLoanLine == nil) {
        _pickerViewLoanLine = [[UIPickerView alloc] init];
        _pickerViewLoanLine.backgroundColor = SGColorFromRGB(0xffffff);
        _pickerViewLoanLine.delegate = self;
        _pickerViewLoanLine.dataSource = self;
        _pickerViewLoanLine.frame = CGRectMake(0, 0, kScreenWidth - 70 - 30, 230);
        
    }
    return _pickerViewLoanLine;
}

- (UIToolbar *)toolBarTwo {
    
    if (_toolBarTwo == nil) {
        
        _toolBarTwo = [self setToolbarStyle:self.titleString andCancel:self.leftString andSure:self.rightString];
    }
    
    return _toolBarTwo;
}

- (UIToolbar *)setToolbarStyle:(NSString *)titleString andCancel:(NSString *)cancelString andSure:(NSString *)sureString{
    
    UIToolbar *toolbar=[[UIToolbar alloc] init];
    toolbar.frame = CGRectMake(0, 0, CCPWIDTH, 40);
    
    UILabel *lable = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CCPWIDTH , 40)];
    lable.backgroundColor = SGColorFromRGB(0xffffff);
    lable.text = titleString;
    lable.textAlignment = 1;
    lable.textColor = SGColorFromRGB(0x24374E);
    lable.numberOfLines = 1;
    lable.font = [UIFont systemFontOfSize:18];
    [toolbar addSubview:lable];
    
    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    cancelBtn.backgroundColor = [UIColor clearColor];
    cancelBtn.frame = CGRectMake(0, 5, 40, 35);
    cancelBtn.titleLabel.font = [UIFont systemFontOfSize:15];
    cancelBtn.layer.cornerRadius = 2;
    cancelBtn.layer.masksToBounds = YES;
    [cancelBtn setTitleColor:SGColorFromRGB(0x24374E) forState:UIControlStateNormal];
    
    [cancelBtn setTitle:cancelString forState:UIControlStateNormal];
    [cancelBtn addTarget:self action:@selector(remove:) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *chooseBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    chooseBtn.backgroundColor = [UIColor clearColor];
    chooseBtn.frame = CGRectMake(0, 5, 40, 35);
    chooseBtn.titleLabel.font = [UIFont systemFontOfSize:15];
    chooseBtn.layer.cornerRadius = 2;
    chooseBtn.layer.masksToBounds = YES;
    [chooseBtn setTitleColor:SGColorFromRGB(0x24374E) forState:UIControlStateNormal];
    
    [chooseBtn setTitle:sureString forState:UIControlStateNormal];
    [chooseBtn addTarget:self action:@selector(doneItemClick:) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *leftItem=[[UIBarButtonItem alloc] initWithCustomView:cancelBtn];
    
    UIBarButtonItem *centerSpace=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    centerSpace.width = 70;
    
    UIBarButtonItem *rightItem=[[UIBarButtonItem alloc] initWithCustomView:chooseBtn];
    
    toolbar.items=@[leftItem,centerSpace,rightItem];
    toolbar.backgroundColor = [UIColor greenColor];
    
    return toolbar;
}

- (UIView *)containerView {
    
    if (_containerView == nil) {
        
        _containerView = [[UIView alloc] initWithFrame:self.frame];

        [_containerView addSubview:self.pickerViewLoanLine];
        
    }
    return _containerView;
    
}

-  (instancetype)initWithpickerViewWithCenterTitle:(NSString *)title andCancel:(NSString *)cancel andSure:(NSString *)sure andDataArray:(NSMutableArray *)array{
    
    if (self = [super initWithFrame:[UIScreen mainScreen].bounds]) {
        _dateArray = array;
        self.string1 = _dateArray[0];
        self.string2 = _dateArray[0];
        self.titleString = title;
        self.leftString = cancel;
        self.rightString = sure;
        [self addSubview:self.containerView];
        UIWindow *currentWindows = [UIApplication sharedApplication].keyWindow;
        self.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.2];
        [currentWindows addSubview:self];
        
        
        
    }
    
    return self;
}

- (instancetype)initWithpickerViewWithDataArray:(NSMutableArray *)array stime:(NSString *)stime etime:(NSString *)etime
{
    if (self = [super initWithFrame:[UIScreen mainScreen].bounds]) {
        _dateArray = array;
        
        self.string1 = FZM_IS_NULL(etime) ? _dateArray[0] : [etime substringWithRange:NSMakeRange(0, 7)];
        self.string2 = FZM_IS_NULL(stime) ? _dateArray[0] : [stime substringWithRange:NSMakeRange(0, 7)];
        [self addSubview:self.containerView];
        
        NSInteger erow = [self.dateArray indexOfObject:self.string1];
        if (erow >= 0
            && erow < self.dateArray.count )
        {
            [self.pickerViewLoanLine selectRow:erow inComponent:0 animated:YES];
        }
        
        NSInteger srow = [self.dateArray indexOfObject:self.string2];
        if (srow >= 0
            && srow < self.dateArray.count)
        {
            [self.pickerViewLoanLine selectRow:srow inComponent:2 animated:YES];
        }
        
        
        UIWindow *currentWindows = [UIApplication sharedApplication].keyWindow;
        self.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.2];
        [currentWindows addSubview:self];
    }
    
    return self;
}


- (void)pickerVIewClickCancelBtnBlock:(clickCancelBtn)cancelBlock
                          sureBtClcik:(clickSureBtn)sureBlock {
    
    self.clickCancelBtn = cancelBlock;
    
    self.clickSureBtn = sureBlock;
    
}

//点击取消按钮
- (void)remove:(UIButton *) btn {
    
    if (self.clickCancelBtn) {
        
        self.clickCancelBtn();
        
    }
    [self dissMissView];
    
}



- (void)dissMissView{
    
    [UIView animateWithDuration:0.3 animations:^{
        [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
        self.containerView.frame = CGRectMake(0, CCPHEIGHT, CCPWIDTH, 256);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

//点击确定按钮
- (void)doneItemClick:(UIButton *) btn {
    
    NSString *leftString = nil;
    NSString *rightString = nil;
    NSString *leftAndRightString = nil;
 
    if (self.index1 > self.index2) {
        [[UIApplication sharedApplication].keyWindow.rootViewController showCustomMessage:@"请正确选择时间区间" hideAfterDelay:2.f];
    } else if (self.index1 == self.index2 ) {
        
        
        leftString = self.string1;
        rightString = self.string2;
        
        leftAndRightString = [NSString stringWithFormat:@"%@至%@",self.string1,self.string2];
        
    }else {
        
        leftAndRightString = [NSString stringWithFormat:@"%@至%@",self.string1,self.string2];
        
        leftString = self.string1;
    
        rightString = self.string2;

        
        
    }
    
    
    if (self.clickSureBtn) {
        
        self.clickSureBtn(leftString,rightString,leftAndRightString);
        
    }
    
    [self dissMissView];
}

- (void)setStime:(NSString *)stime
{
    self.string2 = stime;
    
    NSInteger row = [self.dateArray indexOfObject:self.string2];
    
    [self.pickerViewLoanLine selectRow:row inComponent:2 animated:YES];
}

- (void)setEtime:(NSString *)etime
{
    self.string1 = etime;
    
    NSInteger row = [self.dateArray indexOfObject:self.string1];
    [self.pickerViewLoanLine selectRow:row inComponent:0 animated:YES];
}

#pragma pickerViewDelegate
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    
    return 3;
    
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    
    if (component == 0) {
        
        return self.dateArray.count;
        
    } else if (component == 1) {
        
        return 1;
        
    } else {
        
        return self.dateArray.count;
    }

}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    switch (component) {
        case 0:
            
            return  self.dateArray[row];
            
            break;
            
        case 1:
            
            return  @"至";
            
            break;
        case 2:
            
            return  self.dateArray[row];
            
            break;
            
        default:
            return nil;
    }

}

// 选中某一组中的某一行时调用
- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    
    NSString *selStr = self.dateArray[row];

    switch(component) {
        case 0:
        {
            UIView *view = [self pickerView:pickerView viewForRow:row forComponent:component reusingView:nil];
            UILabel *lab = (UILabel *)view;

            lab.backgroundColor = SGColorFromRGB(0xf3f3f3);
            lab.layer.cornerRadius = 5.f;
            self.string1 = selStr;
            
            self.index1 = [self.dateArray indexOfObject:selStr];
            
            if (self.index1 < self.index2) {
                
            } else {
                
                [self.pickerViewLoanLine selectRow:row inComponent:2 animated:YES];
                self.index2 = self.index1;
                
                self.string2 = self.string1;
            }
        }
            break;
            
        case 2:
        {
            UIView *view = [self pickerView:pickerView viewForRow:row forComponent:component reusingView:nil];
            UILabel *lab = (UILabel *)view;
            
            lab.backgroundColor = SGColorFromRGB(0xf3f3f3);
            lab.layer.cornerRadius = 5.f;
            
            self.string2 = selStr;
            
            self.index2 = [self.dateArray indexOfObject:selStr];
            
            if (self.index2 < self.index1) {
                
                [self.pickerViewLoanLine selectRow:self.index1 inComponent:2 animated:YES];
                
                self.string2 = self.dateArray[self.index1];
                
                self.index2 = self.index1;
                
            } else {
                
                self.string2 = self.dateArray[self.index2];
                
            }
        }
        default:
            break;
    }
    
    NSString *leftandrightStr = [NSString stringWithFormat:@"%@至%@",self.string1,self.string2];
    
    if (self.clickSureBtn) {
        self.clickSureBtn(self.string1, self.string2, leftandrightStr);
    }

}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    
    for (UIView *singleLine in pickerView.subviews)
    {
        if (singleLine.frame.size.height < 1)
        {
            singleLine.backgroundColor = [UIColor clearColor];
            [singleLine removeFromSuperview];
        }
    }
    
    
    UILabel* pickerLabel = (UILabel*)view;
    if (!pickerLabel){
        
        pickerLabel = [[UILabel alloc] init];
        pickerLabel.font = [UIFont systemFontOfSize:17];
        pickerLabel.textColor = SGColorFromRGB(0x24374E);
        [pickerLabel setTextAlignment:NSTextAlignmentCenter];
    }
    pickerLabel.text=[self pickerView:pickerView titleForRow:row forComponent:component];
    return pickerLabel;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component
{
    switch (component) {
        case 0:
        {
            return 120.f;
            
        }
            break;
        case 1:
        {
            return 18.f;
        }
            break;
        case 2:
        {
            return 120.f;
        }
            break;
        default:
        {
            return 120.f;
        }
            break;
    }
    return 120.f;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return 40.f;
}

@end
