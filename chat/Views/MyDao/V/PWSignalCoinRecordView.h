//
//  PWSignalCoinRecordView.h
//  PWallet
//
//  Created by 郑晨 on 2021/7/12.
//  Copyright © 2021 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^RecordListBlock)(void);

@interface PWSignalCoinRecordView : UIView

@property (nonatomic, strong) UILabel *recordCountLab;
@property (nonatomic, strong) UIButton *recordBtn;
@property (nonatomic, assign) NSInteger recordCount;
@property (nonatomic) RecordListBlock recordListBlock;

@end

NS_ASSUME_NONNULL_END
