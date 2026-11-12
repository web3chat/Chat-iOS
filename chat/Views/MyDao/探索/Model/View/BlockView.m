//
//  BlockView.m
//  PWallet
//
//  Created by 宋刚 on 2019/3/20.
//  Copyright © 2019年 fzm. All rights reserved.
//

#import "BlockView.h"
#import "Depend.h"
@interface BlockView()
@property (nonatomic,copy)NSArray *images;
@property (nonatomic,copy)NSArray *texts;
@property (nonatomic,copy)NSString *title;
@end
@implementation BlockView

- (instancetype)initTexts:(NSArray *)texts Title:(NSString *)title{
    self = [super init];
    if (self) {
        _texts = texts;
        _title = title;
        [self createView];
    }
    return self;
}


- (void)createView{
    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.textColor = CMColor(51, 54, 73);
    titleLab.font = [UIFont boldSystemFontOfSize:18];
    titleLab.textAlignment = NSTextAlignmentLeft;
    titleLab.text = _title;
    [self addSubview:titleLab];
    titleLab.frame = CGRectMake(27, 0, kScreenWidth, 40);
    
    for(int i = 0;i < _texts.count;i++){
        
        NSString *text = [_texts objectAtIndex:i];
        UIImageView *icon = [[UIImageView alloc] init];
        int width = (kScreenWidth - 32 *3 -27 *2)/4;
        icon.frame = CGRectMake(27 + (width + 32)*(i%4), 48 + (49 + width)*(i /4), width, width);
        icon.layer.cornerRadius = width/2;
        icon.layer.masksToBounds = YES;
        [icon setImage:[UIImage imageNamed:text]];
        icon.tag = i;
        [self addSubview:icon];
        
        icon.userInteractionEnabled=YES;
        UITapGestureRecognizer *singleTap =[[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(itemClickAction:)];
        [icon addGestureRecognizer:singleTap];
        
        int textwidth = width + 20;
        UILabel *textLab = [[UILabel alloc] init];
        textLab.textAlignment = NSTextAlignmentCenter;
        textLab.font = CMTextFont14;
        textLab.text = text;
        textLab.textColor = CMColor(101, 103, 117);
        textLab.frame = CGRectMake(0, 0, textwidth, 20);
        [textLab setCenter:CGPointMake(icon.center.x, icon.center.y + 50)];
       
        [self addSubview:textLab];
        
    }
}

- (void)itemClickAction:(UITapGestureRecognizer *)tap{
    UIImageView *imgView = (UIImageView *)tap.view;
    self.itemAction(imgView.tag);
}
@end
