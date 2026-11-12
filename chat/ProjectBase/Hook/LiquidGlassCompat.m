//
//  LiquidGlassCompat.m
//  chat
//
//  iOS 26/27「液态玻璃」适配。
//
//  为什么需要这个文件：
//  · 产品要求**关闭** iOS 26+ 的系统液态玻璃（顶部导航栏保持 App 自己的纯色设计）；
//  · `UIBarButtonItem` 在 iOS 26+ 会被系统自动套一个「玻璃胶囊」背景，
//    关掉它的官方开关是 `hidesSharedBackground`（iOS 26 新增，见 UIBarButtonItem.h）；
//  · `UINavigationBarAppearance` 只设 `backgroundColor` 时，系统仍按玻璃材质绘制，
//    必须再给一张**纯色 backgroundImage** 才会真正画成不透明。
//
//  这里用运行时挂钩统一处理，避免去改 30+ 个页面的导航栏代码。
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - UINavigationItem：去掉 bar button 的玻璃胶囊

@interface UINavigationItem (LGLiquidGlass)
- (void)lg_setLeftBarButtonItem:(nullable UIBarButtonItem *)item;
- (void)lg_setRightBarButtonItem:(nullable UIBarButtonItem *)item;
- (void)lg_setLeftBarButtonItems:(nullable NSArray<UIBarButtonItem *> *)items;
- (void)lg_setRightBarButtonItems:(nullable NSArray<UIBarButtonItem *> *)items;
@end

static void LGApplyToBarButtonItem(UIBarButtonItem *item) {
    if (![item isKindOfClass:[UIBarButtonItem class]]) return;
    if (@available(iOS 26.0, *)) {
        item.hidesSharedBackground = YES;
    }
}

@implementation UINavigationItem (LGLiquidGlass)

+ (void)lg_swizzleInstanceMethod:(SEL)original selector:(SEL)replacement {
    Method origin = class_getInstanceMethod(self, original);
    Method replace = class_getInstanceMethod(self, replacement);
    if (origin && replace) {
        method_exchangeImplementations(origin, replace);
    }
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self lg_swizzleInstanceMethod:@selector(setLeftBarButtonItem:)
                              selector:@selector(lg_setLeftBarButtonItem:)];
        [self lg_swizzleInstanceMethod:@selector(setRightBarButtonItem:)
                              selector:@selector(lg_setRightBarButtonItem:)];
        [self lg_swizzleInstanceMethod:@selector(setLeftBarButtonItems:)
                              selector:@selector(lg_setLeftBarButtonItems:)];
        [self lg_swizzleInstanceMethod:@selector(setRightBarButtonItems:)
                              selector:@selector(lg_setRightBarButtonItems:)];
    });
}

- (void)lg_setLeftBarButtonItem:(nullable UIBarButtonItem *)item {
    LGApplyToBarButtonItem(item);
    [self lg_setLeftBarButtonItem:item];
}

- (void)lg_setRightBarButtonItem:(nullable UIBarButtonItem *)item {
    LGApplyToBarButtonItem(item);
    [self lg_setRightBarButtonItem:item];
}

- (void)lg_setLeftBarButtonItems:(nullable NSArray<UIBarButtonItem *> *)items {
    for (UIBarButtonItem *item in items) { LGApplyToBarButtonItem(item); }
    [self lg_setLeftBarButtonItems:items];
}

- (void)lg_setRightBarButtonItems:(nullable NSArray<UIBarButtonItem *> *)items {
    for (UIBarButtonItem *item in items) { LGApplyToBarButtonItem(item); }
    [self lg_setRightBarButtonItems:items];
}

@end

#pragma mark - UINavigationBar：外观里补一张纯色 backgroundImage

@interface UINavigationBar (LGLiquidGlass)
- (void)lg_setStandardAppearance:(UINavigationBarAppearance *)appearance;
- (void)lg_setCompactAppearance:(nullable UINavigationBarAppearance *)appearance;
- (void)lg_setScrollEdgeAppearance:(nullable UINavigationBarAppearance *)appearance;
- (void)lg_setCompactScrollEdgeAppearance:(nullable UINavigationBarAppearance *)appearance;
@end

@implementation UINavigationBar (LGLiquidGlass)

+ (void)lg_swizzleAppearanceMethod:(SEL)original selector:(SEL)replacement {
    Method origin = class_getInstanceMethod(self, original);
    Method replace = class_getInstanceMethod(self, replacement);
    if (origin && replace) {
        method_exchangeImplementations(origin, replace);
    }
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (@available(iOS 15.0, *)) {
            [self lg_swizzleAppearanceMethod:@selector(setStandardAppearance:)
                                    selector:@selector(lg_setStandardAppearance:)];
            [self lg_swizzleAppearanceMethod:@selector(setCompactAppearance:)
                                    selector:@selector(lg_setCompactAppearance:)];
            [self lg_swizzleAppearanceMethod:@selector(setScrollEdgeAppearance:)
                                    selector:@selector(lg_setScrollEdgeAppearance:)];
            [self lg_swizzleAppearanceMethod:@selector(setCompactScrollEdgeAppearance:)
                                    selector:@selector(lg_setCompactScrollEdgeAppearance:)];
        }
    });
}

/// 关掉玻璃材质：backgroundEffect 置 nil + 用一张 1×1 纯色图当背景。
/// 只处理「明确设了不透明背景色」的外观，透明外观（backgroundImage 用作图片头图的那种）保持原样。
static void LGTuneNavigationBarAppearance(UINavigationBarAppearance *appearance) {
    if (![appearance isKindOfClass:[UINavigationBarAppearance class]]) return;

    UIColor *color = appearance.backgroundColor;
    BOOL hasSolidColor = color != nil && CGColorGetAlpha(color.CGColor) > 0.01;
    if (hasSolidColor) {
        appearance.backgroundEffect = nil;
        UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
        format.opaque = YES;
        format.scale = 1;
        UIGraphicsImageRenderer *renderer =
            [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(1, 1) format:format];
        appearance.backgroundImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
            [color setFill];
            [ctx fillRect:CGRectMake(0, 0, 1, 1)];
        }];
        appearance.backgroundImageContentMode = UIViewContentModeScaleToFill;
        appearance.shadowColor = UIColor.clearColor;
    }

    // 老 API 兜底：清掉 bar button 的背景图（部分 iOS 26 小版本仍会用它画胶囊）
    UIBarButtonItemAppearance *buttonAppearance = appearance.buttonAppearance;
    buttonAppearance.normal.backgroundImage = [UIImage new];
    buttonAppearance.highlighted.backgroundImage = [UIImage new];
    appearance.doneButtonAppearance.normal.backgroundImage = [UIImage new];
    appearance.doneButtonAppearance.highlighted.backgroundImage = [UIImage new];
    appearance.backButtonAppearance.normal.backgroundImage = [UIImage new];
    appearance.backButtonAppearance.highlighted.backgroundImage = [UIImage new];
}

- (void)lg_setStandardAppearance:(UINavigationBarAppearance *)appearance {
    LGTuneNavigationBarAppearance(appearance);
    [self lg_setStandardAppearance:appearance];
}

- (void)lg_setCompactAppearance:(nullable UINavigationBarAppearance *)appearance {
    LGTuneNavigationBarAppearance(appearance);
    [self lg_setCompactAppearance:appearance];
}

- (void)lg_setScrollEdgeAppearance:(nullable UINavigationBarAppearance *)appearance {
    LGTuneNavigationBarAppearance(appearance);
    [self lg_setScrollEdgeAppearance:appearance];
}

- (void)lg_setCompactScrollEdgeAppearance:(nullable UINavigationBarAppearance *)appearance {
    LGTuneNavigationBarAppearance(appearance);
    [self lg_setCompactScrollEdgeAppearance:appearance];
}

@end
