//
//  XLSLoader.m
//  xls
//
//  Created by 陈健 on 2020/7/31.
//  Copyright © 2020 陈健. All rights reserved.
//

#import "XLSLoader.h"
#import <chat-Swift.h>
#import <objc/runtime.h>


//static inline BOOL xls_addMethod(Class theClass, SEL selector, Method method) {
//    return class_addMethod(theClass, selector,  method_getImplementation(method),  method_getTypeEncoding(method));
//}

static inline void xls_swizzleSelector(Class theClass, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(theClass, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(theClass, swizzledSelector);
    method_exchangeImplementations(originalMethod, swizzledMethod);
}

@implementation XLSLoader
+ (void)load {
    [ViewControllerIntercepter shared];
    [AppDelegateIntercepter shared];
}

@end


#pragma mark -------------- UIViewController (Hook) --------------

@interface UIViewController (Hook)

@end

@implementation UIViewController (Hook)

+ (void)load {
    [self swizzleMethod];
}

+ (void)swizzleMethod {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = self;
        
        xls_swizzleSelector(class, @selector(viewDidLoad), @selector(xls_viewDidLoad));

        xls_swizzleSelector(class, @selector(viewWillAppear:), @selector(xls_viewWillAppear:));
        
        xls_swizzleSelector(class, @selector(viewDidAppear:), @selector(xls_viewDidAppear:));
        
        xls_swizzleSelector(class, @selector(viewWillDisappear:), @selector(xls_viewWillDisappear:));
        
        xls_swizzleSelector(class, @selector(viewDidDisappear:), @selector(xls_viewDidDisappear:));
        
        xls_swizzleSelector(class, NSSelectorFromString(@"dealloc"), @selector(xls_dealloc));
    });
}

- (void)xls_viewDidLoad {
    [self xls_viewDidLoad];
    [[ViewControllerIntercepter shared] viewDidLoad:self];
}

- (void)xls_viewWillAppear:(BOOL)animated {
    [self xls_viewWillAppear:animated];
    [[ViewControllerIntercepter shared] viewWillAppear:animated : self];
}

- (void)xls_viewDidAppear:(BOOL)animated {
    [self xls_viewDidAppear:animated];
    
    [[ViewControllerIntercepter shared] viewDidAppear:animated :self];
}

- (void)xls_viewWillDisappear:(BOOL)animated {
    [self xls_viewWillDisappear:animated];
    
    [[ViewControllerIntercepter shared] viewWillDisappear:animated :self];
}

- (void)xls_viewDidDisappear:(BOOL)animated {
    [self xls_viewDidDisappear:animated];
}

- (void)xls_dealloc {
    [[ViewControllerIntercepter shared] controllerDeinit:self];
        
    [self xls_dealloc];
}

@end

