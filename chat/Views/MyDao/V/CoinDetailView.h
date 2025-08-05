//
//  CoinDetailView.h
//  PWallet
//
//  Created by 宋刚 on 2018/5/29.
//  Copyright © 2018年 陈健. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LocalCoin.h"
#import "CoinPrice.h"
#import "PWDataBaseManager.h"
#import <YYWebImage/YYWebImage.h>
typedef void(^CoinDetailViewCopyAddressBlock)(NSString*);
typedef void(^CoinDetailViewQRCodeBlock)(UIImageView *);
typedef void(^CoinDetailViewNFTURLBlock)(void);
@interface CoinDetailView : UIView
@property (nonatomic,copy) LocalCoin *coin;
@property (nonatomic,strong)UILabel *rmbLab;
@property (nonatomic,strong)UILabel *balanceLab;
@property (nonatomic,strong)UIImageView *coinImage;
@property (nonatomic,weak) UIButton *qrCodeBtn;
@property (nonatomic, strong) YYAnimatedImageView *animatedImageView;
/*复制地址回调**/
@property (nonatomic, copy)CoinDetailViewCopyAddressBlock copyAddressBlock;
@property (nonatomic, copy)CoinDetailViewQRCodeBlock qrCodeBlock;
@property (nonatomic, copy) CoinDetailViewNFTURLBlock nfturlBlock;
@end

