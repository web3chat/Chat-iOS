//
//  CustomEmojiView.m
//  chat
//
//  Created by liyaqin on 2021/9/14.
//

#import "CustomEmojiView.h"

#define color_Theme 0x32B2F7

#define UIColorFromRGB(rgbValue) [UIColor                       \
colorWithRed:((float)((rgbValue & 0xFF0000) >> 16)) / 255.0 \
green:((float)((rgbValue & 0xFF00) >> 8)) / 255.0    \
blue:((float)(rgbValue & 0xFF)) / 255.0             \
alpha:1.0]

#define SCREEN_WIDTH UIScreen.mainScreen.bounds.size.width
//将数字转为
#define EMOJI_CODE_TO_SYMBOL(x) ((((0x808080F0 | (x & 0x3F000) >> 4) | (x & 0xFC0) << 10) | (x & 0x1C0000) << 18) | (x & 0x3F) << 24);

@interface CustomEmojiView () <UICollectionViewDelegate,UICollectionViewDataSource>

@end

@implementation CustomEmojiView
{
    NSMutableArray *emojiArray;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = UIColor.whiteColor;
//        emojiArray = [self defaultEmoticons];
        NSString *jsonPath = [[NSBundle mainBundle] pathForResource:@"emoji" ofType:@"json"];
        NSData *data = [NSData dataWithContentsOfFile:jsonPath];
        NSError *error = nil;
        NSArray *result = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
        emojiArray = [NSMutableArray arrayWithCapacity:1];
        for (NSDictionary *dict in result) {
            NSString *emojiStr = [self replaceUnicode:[dict objectForKey:@"keyCode"]];
            [emojiArray addObject:emojiStr];
            
        }
        [self createUI];
    }
    return self;
}

- (void)createUI {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    UICollectionView *myCollectionView = [[UICollectionView alloc]initWithFrame:CGRectMake(10, 0, SCREEN_WIDTH-20, 200) collectionViewLayout:layout];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.itemSize = CGSizeMake(30, 30);
    [self addSubview:myCollectionView];
    myCollectionView.delegate = self;
    myCollectionView.dataSource = self;
    myCollectionView.backgroundColor = UIColor.whiteColor;
    myCollectionView.showsVerticalScrollIndicator = YES;
    [myCollectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"emojiCell"];
    
    UIView *emojiFooter = [[UIView alloc]initWithFrame:CGRectMake(0, 200, SCREEN_WIDTH, 70)];
    emojiFooter.backgroundColor = [UIColor whiteColor];
    [self addSubview:emojiFooter];
    
    UIButton *sendEmojiBtn = [[UIButton alloc]initWithFrame:CGRectMake(emojiFooter.frame.size.width - 60, 0, 50, 50)];
    [sendEmojiBtn setTitle:@"发送" forState:UIControlStateNormal];
    [sendEmojiBtn setTitleColor:UIColorFromRGB(color_Theme) forState:UIControlStateNormal];
    sendEmojiBtn.backgroundColor = UIColor.whiteColor;
    sendEmojiBtn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
    [emojiFooter addSubview:sendEmojiBtn];
    [sendEmojiBtn addTarget:self action:@selector(sendEmoji) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *deleteBtn = [[UIButton alloc]initWithFrame:CGRectMake(emojiFooter.frame.size.width - 110, 0, 50, 50)];
    [deleteBtn setTitleColor:UIColorFromRGB(color_Theme) forState:UIControlStateNormal];
    deleteBtn.backgroundColor = UIColor.whiteColor;
    deleteBtn.tintColor = UIColorFromRGB(color_Theme);
    [emojiFooter addSubview:deleteBtn];
    UIImage *img = [UIImage imageNamed:@"emojiDelete"];
    [deleteBtn setImage:[img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
    [deleteBtn addTarget:self action:@selector(deleteBtnEmoji) forControlEvents:UIControlEventTouchUpInside];
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return emojiArray.count;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"emojiCell";
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:identifier forIndexPath:indexPath];
    if (!cell) {
        cell = [[UICollectionViewCell alloc]init];
    }
    
    [self setCell:cell withIndexPath:indexPath];
    
    return cell;
}

- (void)setCell:(UICollectionViewCell *)cell withIndexPath:(NSIndexPath *)indexPath {
    [cell.contentView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    UILabel *emojiLabel = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, 30, 30)];
    emojiLabel.text = emojiArray[indexPath.section * 24 + indexPath.row];
    emojiLabel.font = [UIFont systemFontOfSize:25];
    [cell.contentView addSubview:emojiLabel];
}

//-(UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section
//{
//    return UIEdgeInsetsMake(0, 10, 0, 10);//分别为上、左、下、右
//}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *emojiStr = emojiArray[indexPath.row];
    //NSLog(@"表情 %@", emojiStr);
    if (self.delegate && [self.delegate respondsToSelector:@selector(didClickEmojiLabel:)]) {
        [self.delegate didClickEmojiLabel:emojiStr];
    }
}

//发送表情
- (void)sendEmoji {
    if (self.delegate && [self.delegate respondsToSelector:@selector(didClickSendEmojiBtn)]) {
        [self.delegate didClickSendEmojiBtn];
    }
}

- (void)deleteBtnEmoji{
    if (self.delegate && [self.delegate respondsToSelector:@selector(didDeleteEmojiBtn)]) {
        [self.delegate didDeleteEmojiBtn];
    }
}
//表情包
- (NSArray *)defaultEmoticons {
    NSMutableArray *array = [NSMutableArray new];
    for (int i = 0x1F600; i <= 0x1F64F; i++) {
        if (i < 0x1F641 || i > 0x1F644) {
            int sym = EMOJI_CODE_TO_SYMBOL(i);
            NSString *emoT = [[NSString alloc] initWithBytes:&sym length:sizeof(sym) encoding:NSUTF8StringEncoding];
            [array addObject:emoT];
        }
    }
    return array;
}


//unicode格式解码
- (NSString *)replaceUnicode:(NSString*)unicodeStr{
    
    NSString *tempStr1=[unicodeStr stringByReplacingOccurrencesOfString:@"\\u"withString:@"\\U"];
    NSString *tempStr2=[tempStr1 stringByReplacingOccurrencesOfString:@"\""withString:@"\\\""];
    NSString *tempStr3=[[@"\"" stringByAppendingString:tempStr2]stringByAppendingString:@"\""];
    NSData *tempData=[tempStr3 dataUsingEncoding:NSUTF8StringEncoding];
    NSString *returnStr = [NSPropertyListSerialization propertyListWithData:tempData options:NSPropertyListImmutable format:NULL error:NULL];
    
    return [returnStr stringByReplacingOccurrencesOfString:@"\\r\\n"withString:@"\n"];
    
}

@end
