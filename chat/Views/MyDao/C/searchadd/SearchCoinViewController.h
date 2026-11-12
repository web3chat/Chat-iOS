//
//  SearchCoinViewController.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/28.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Depend.h"
#import "UISearchBar+SearchBarPlaceholder.h"
#import "CoinTableViewCell.h"
#import <MJRefresh/MJRefresh.h>
#import <Walletapi/Walletapi.h>
#import "NoRecordView.h"

typedef void(^VCDismissBlock)(void);
@interface SearchCoinViewController : CommonViewController

@property (nonatomic) VCDismissBlock dismissBlock;

@end
