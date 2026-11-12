//
//  ScanViewController.m
//  PWallet
//
//  Created by 宋刚 on 2018/3/21.
//  Copyright © 2018年 宋刚. All rights reserved.
//

#import "ScanViewController.h"
#import "SGQRCode.h"
#import "PWAuthorizationTool.h"
#import "PWDataBaseManager.h"
#import "PWScanResultStatusView.h"
#import "Depend.h"
#import <Masonry/Masonry.h>
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
@interface ScanViewController (){
    SGQRCodeObtain *obtain;
}
- (void)pickQRCodeFromAlbum;
@property (nonatomic, strong) SGQRCodeScanView *scanView;
@property (nonatomic, strong) UIButton *flashlightBtn;
@property (nonatomic, strong) UILabel *promptLabel;
@property (nonatomic, assign) BOOL isSelectedFlashlightBtn;
@property (nonatomic, strong) UIView *bottomView;
@property (nonatomic,strong) UIView *titleView;
@property (nonatomic,strong)NSMutableArray *resultArray;
@property (nonatomic,strong)NSMutableArray *handleArray;
@property (nonatomic,strong)NSMutableArray *strArray;
@property (nonatomic,copy)NSString *resultString;
@property(nonatomic,copy)NSString *isLastStr;
@end

@implementation ScanViewController


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 二维码开启方法
    [obtain startRunningWithBefore:nil completion:nil];
    [self.view bringSubviewToFront:self.titleView];
    
   
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.scanView addTimer];
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = false;
    [self.scanView removeTimer];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self removeFlashlightBtn];
    [obtain stopRunning];
}

- (void)dealloc {
    NSLog(@"ScanViewController - dealloc");
    [self removeScanningView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // 用 setNavigationBarHidden 而不是 navigationBar.hidden：后者不会同步 isNavigationBarHidden 状态，
    // 退回上一页后导航栏会“看着回来了，实际还是隐藏状态”，再 push 就没返回键了。
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    self.showMaskLine = false;
    self.statusBarStyle = UIStatusBarStyleLightContent;
    // Do any additional setup after loading the view from its nib.
    self.view.backgroundColor = [UIColor blackColor];
    [self createBackBtn];
    [self.view bringSubviewToFront:self.titleView];
    //检测相机权限
    [PWAuthorizationTool detectionCameraAuthorized:^{
        // 这里是摄像头可以使用的处理逻辑
        self->obtain = [SGQRCodeObtain QRCodeObtain];
        [self setupQRCodeScan];
        [self.view addSubview:self.scanView];
        [self.view addSubview:self.promptLabel];
        /// 为了 UI 效果
        [self.view addSubview:self.bottomView];
        
        [self->obtain startRunningWithBefore:nil completion:nil];
    } Denied:^{
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:L(@"摄像头") message:L(@"请前往设置打开摄像头权限") preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action1 = [UIAlertAction actionWithTitle:L(@"确定")  style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString] options:@{} completionHandler:nil];
           
            [self.navigationController popViewControllerAnimated:false];
        }];
        UIAlertAction *action2 = [UIAlertAction actionWithTitle:L(@"取消")  style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            [self.navigationController popViewControllerAnimated:true];
        }];
        [alertVC addAction:action2];
        [alertVC addAction:action1];
        
        [self presentViewController:alertVC animated:true completion:nil];
    }];
    self.strArray = [NSMutableArray arrayWithCapacity:20];
}

- (void)createBackBtn
{
    UIView *titleView = [[UIView alloc] init];
    titleView.frame = CGRectMake(0, 0, SCREENBOUNDS.size.width,kTopOffset);
    titleView.backgroundColor = CMColorRGBA(0, 0, 0, 0);
    [self.view addSubview:titleView];
    self.titleView = titleView;
    self.titleView.userInteractionEnabled = true;
    CGFloat y = kTopOffset;
    
    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.text = L(@"扫一扫") ;
    titleLab.textColor = [UIColor whiteColor];
    titleLab.font = [UIFont boldSystemFontOfSize:18];
    titleLab.textAlignment = NSTextAlignmentCenter;
    titleLab.frame = CGRectMake(0, y, SCREENBOUNDS.size.width, 40);
    [self.titleView addSubview:titleLab];
    
    UIImage *backImg = [UIImage imageNamed:@"返回箭头"];
    UIButton *backBtn = [[UIButton alloc] init];
    [backBtn setImage:backImg forState:UIControlStateNormal];
    [backBtn setTitle:@"    " forState:UIControlStateNormal];
    backBtn.frame = CGRectMake(16, y, 40, 40);
    [self.titleView addSubview:backBtn];
    [backBtn addTarget:self action:@selector(backBtnClickAction) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *photosBtn = [[UIButton alloc] init];
    [photosBtn setTitle:L(@"相册")  forState:UIControlStateNormal];
    [photosBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    photosBtn.titleLabel.font = CMTextFont15;
    [self.titleView addSubview:photosBtn];
    [photosBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(@-10);
        make.top.mas_equalTo(y);
        make.height.equalTo(@40);
    }];

//    photosBtn.frame = CGRectMake(SCREENBOUNDS.size.width - 110, y, 100, 40);
    
    [photosBtn addTarget:self action:@selector(rightBarButtonItenAction) forControlEvents:UIControlEventTouchUpInside];
    
}

/**
 * 返回按钮点击事件
 */
- (void)backBtnClickAction
{
    [self.navigationController popViewControllerAnimated:true];
}

- (void)setupQRCodeScan {
    __weak typeof(self) weakSelf = self;
    SGQRCodeObtainConfigure *configure = [SGQRCodeObtainConfigure QRCodeObtainConfigure];
    configure.sampleBufferDelegate = YES;
    NSArray *arr = @[AVMetadataObjectTypeQRCode, AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code];
    configure.metadataObjectTypes = arr;
    [obtain establishQRCodeObtainScanWithController:self configure:configure];
    [obtain setBlockWithQRCodeObtainScanResult:^(SGQRCodeObtain *obtain, NSString *result) {
        if (result) {
            if (self.fromType != 1 && self.fromType != 2) {
                [obtain playSoundName:@"SGQRCode.bundle/sound.caf"];
            }
            if (weakSelf.scanResult) {
                if (self.fromType != 1 && self.fromType != 2) {
                    [obtain stopRunning];
                    [weakSelf.navigationController popViewControllerAnimated:true];
                }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    weakSelf.scanResult(result);
                });
               
            }
        }
    }];

}

- (void)rightBarButtonItenAction {
    // 与聊天发图 / Swift 版扫一扫（QRCodeReaderVC）统一：打开相册前先过权限检查，
    // 然后用系统 PHPicker 选图（不会再因为「部分照片」只显示几张）。
    [self openPhoto];
}

- (void)openPhoto {
    // 打开系统相册前统一走权限检查（未决定→请求；部分照片→提示；拒绝→去设置）
    __weak typeof(self) weakSelf = self;
    [PhotoLibraryAccess preparePhotoAccessFrom:self limitedMessage:nil onProceed:^{
        [weakSelf pickQRCodeFromAlbum];
    }];
}

/// 权限已就绪后真正打开相册并识别
- (void)pickQRCodeFromAlbum {
    // 选图期间暂停取景动画与扫码，避免重复识别
    [self.scanView removeTimer];
    [obtain stopRunning];

    SGQRCodeObtain *obtainRef = obtain;
    __weak typeof(self) weakSelf = self;
    [SystemMediaPicker pickQRCodeFrom:self completion:^(BOOL cancelled, NSString * _Nullable code) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { return; }

        if (code.length > 0) {
            if (strongSelf.scanResult) {
                [strongSelf.navigationController popViewControllerAnimated:true];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    strongSelf.scanResult(code);
                });
            }
            return;
        }

        // 取消 / 没识别到：恢复取景与扫码（只有识别失败才提示）
        // ⚠️ 先 removeTimer 再 addTimer：SGQRCodeScanView.addTimer 不校验已有定时器，
        // 若 dismiss 时 viewDidAppear 也回调了一次，重复创建会出现两条扫描线/双倍速度。
        [strongSelf.scanView removeTimer];
        [strongSelf.scanView addTimer];
        [obtainRef startRunningWithBefore:nil completion:nil];
        if (!cancelled) {
            [strongSelf showCustomMessage:L(@"解析失败") hideAfterDelay:2.f];
        }
    }];
}

- (SGQRCodeScanView *)scanView {
    if (!_scanView) {
        _scanView = [[SGQRCodeScanView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 0.9 * self.view.frame.size.height)];
    }
    return _scanView;
}
- (void)removeScanningView {
    [self.scanView removeTimer];
    [self.scanView removeFromSuperview];
    self.scanView = nil;
}

- (UILabel *)promptLabel {
    if (!_promptLabel) {
        _promptLabel = [[UILabel alloc] init];
        _promptLabel.backgroundColor = [UIColor clearColor];
        CGFloat promptLabelX = 0;
        CGFloat promptLabelY = 0.73 * self.view.frame.size.height;
        CGFloat promptLabelW = self.view.frame.size.width;
        CGFloat promptLabelH = 25;
        _promptLabel.frame = CGRectMake(promptLabelX, promptLabelY, promptLabelW, promptLabelH);
        _promptLabel.textAlignment = NSTextAlignmentCenter;
        _promptLabel.font = [UIFont systemFontOfSize:15];
        _promptLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
        _promptLabel.text = L(@"请将镜头对准二维码进行扫描") ;
    }
    return _promptLabel;
}

- (UIView *)bottomView {
    if (!_bottomView) {
        _bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.scanView.frame), self.view.frame.size.width, self.view.frame.size.height - CGRectGetMaxY(self.scanView.frame))];
        _bottomView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    }
    return _bottomView;
}

#pragma mark - - - 闪光灯按钮
- (UIButton *)flashlightBtn {
    if (!_flashlightBtn) {
        // 添加闪光灯按钮
        _flashlightBtn = [UIButton buttonWithType:(UIButtonTypeCustom)];
        CGFloat flashlightBtnW = 30;
        CGFloat flashlightBtnH = 30;
        CGFloat flashlightBtnX = 0.5 * (self.view.frame.size.width - flashlightBtnW);
        CGFloat flashlightBtnY = 0.55 * self.view.frame.size.height;
        _flashlightBtn.frame = CGRectMake(flashlightBtnX, flashlightBtnY, flashlightBtnW, flashlightBtnH);
        [_flashlightBtn setBackgroundImage:[UIImage imageNamed:@"SGQRCodeFlashlightOpenImage"] forState:(UIControlStateNormal)];
        [_flashlightBtn setBackgroundImage:[UIImage imageNamed:@"SGQRCodeFlashlightCloseImage"] forState:(UIControlStateSelected)];
        [_flashlightBtn addTarget:self action:@selector(flashlightBtn_action:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _flashlightBtn;
}

- (void)flashlightBtn_action:(UIButton *)button {
    if (button.selected == NO) {
        [obtain openFlashlight];
        self.isSelectedFlashlightBtn = YES;
        button.selected = YES;
    } else {
        [self removeFlashlightBtn];
    }
}

- (void)removeFlashlightBtn {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self->obtain closeFlashlight];
        self.isSelectedFlashlightBtn = NO;
        self.flashlightBtn.selected = NO;
        [self.flashlightBtn removeFromSuperview];
    });
}

- (NSMutableArray *)resultArray{
    if (_resultArray == nil) {
        _resultArray = [NSMutableArray array];
    }
    return _resultArray;
}

- (NSMutableArray *)handleArray{
    if (_handleArray == nil) {
        _handleArray = [NSMutableArray array];
    }
    return _handleArray;
}


@end
