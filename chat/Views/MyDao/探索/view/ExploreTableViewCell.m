//
//  ExploreTableViewCell.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//

#import "ExploreTableViewCell.h"
#import "Depend.h"
#import "chat-Swift.h"

#define L(key) [[LanguageManager shared] localizedStringForKey:key]
@interface ExploreTableViewCell()
@property(nonatomic,strong)UILabel *titleLab;
//@property(nonatomic,strong)UIImageView *imageview;
@end

@implementation ExploreTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self createView];
        self.backgroundColor = SGColorFromRGB(0xFCFCFF);
    }
    return self;
}

- (void)createView
{
    UILabel *titleLab = [[UILabel alloc] init];
    titleLab.text = _titleStr;
    titleLab.textColor = UIColor.whiteColor;
    titleLab.font = [UIFont systemFontOfSize:22];
    titleLab.textAlignment = NSTextAlignmentLeft;
    [self.contentView addSubview:titleLab];
    [titleLab mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self).with.offset(24);
        make.top.equalTo(self).with.offset(30);
    }];
    self.titleLab = titleLab;

}

- (void)setTitleStr:(NSString *)titleStr{
    _titleStr = titleStr;
    _titleLab.text = [titleStr stringByAppendingString:L(@"区块链浏览器")];
}

- (void)setBgImage:(UIImage *)bgImage{
    _bgImage = bgImage;
    [self.imageView setImage:bgImage];
//    _imageview.image = bgImage;
}
@end
