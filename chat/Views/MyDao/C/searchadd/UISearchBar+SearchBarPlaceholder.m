//
//  UISearchBar+SearchBarPlaceholder.m
//  PWallet
//
//  Created by 宋刚 on 2018/5/28.
//  Copyright © 2018年 fzm. All rights reserved.
//

#import "UISearchBar+SearchBarPlaceholder.h"

@implementation UISearchBar (SearchBarPlaceholder)

-(void)changePlaceholderToLeft:(NSString *)placeholder {
    self.placeholder = placeholder;
    SEL centerSelector = NSSelectorFromString([NSString stringWithFormat:@"%@%@", @"setCenter", @"Placeholder:"]);
    if ([self respondsToSelector:centerSelector]) {
        BOOL centeredPlaceholder = NO;
        NSMethodSignature *signature = [[UISearchBar class] instanceMethodSignatureForSelector:centerSelector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:self];
        [invocation setSelector:centerSelector];
        [invocation setArgument:&centeredPlaceholder atIndex:2];
        [invocation invoke];
    }
}

@end
