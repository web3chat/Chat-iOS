//
//  AppsTableVC.m
//  PWallet
//
//  Created by fzm on 2021/12/7.
//
//

#import "AppsTableVC.h"
#import "ExploreCell.h"
#import "RecentlyUsedAppTool.h"
#import "chat-Swift.h"
#import "UIViewController+AppClicked.h"
#import "PWApplication.h"
#import "Depend.h"
@interface AppsTableVC ()<UITableViewDelegate, UITableViewDataSource>
@property(nonatomic,assign)NSInteger sectionID;
@property(nonatomic,copy)NSArray<PWApplication *> * appArr;
@property(nonatomic,strong)UITableView* tableView;
@end
static NSString *const cellIdentity = @"ExploreCell";
@implementation AppsTableVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    [self loadData];
}

- (instancetype)initWitID:(NSInteger)sectionID
{
    self = [super init];
    if (self) {
        self.sectionID = sectionID;
    }
    return self;
}

-(void)loadData{
     NSString* urlStr = [WalletURL stringByAppendingString:Explore_Category];
       
    [PWNetworkingTool getRequestWithUrl:urlStr parameters:@{@"id": [NSString stringWithFormat: @"%ld", (long)self.sectionID]} successBlock:^(id object) {
        self.appArr = [NSArray yy_modelArrayWithClass:[PWApplication class] json:object[0][@"apps"]];
        self.title = object[0][@"name"];
        [self createTableView];
       } failureBlock:^(NSError *error) {
           [self showError:error hideAfterDelay:2];
       }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // 使用系统 UIBarButtonItem（customView 会贴左、且 iOS 26 会被套玻璃胶囊）
    UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"nav_back"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(backAction)];
    leftItem.tintColor = SGColorFromRGB(0x333649);
    self.navigationItem.leftBarButtonItem = leftItem;
}

- (void)backAction{
    [self.navigationController popViewControllerAnimated:YES];
}
#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.appArr.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 76;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ExploreCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentity forIndexPath:indexPath];
    [cell setValueWithApp:self.appArr[indexPath.row]];
    WEAKSELF
    cell.block = ^(){
        [weakSelf appClicked:weakSelf.appArr[indexPath.row]];
    };
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    PWApplication* app = self.appArr[indexPath.row];
    [RecentlyUsedAppTool setAppID:app.appID];
    
    NSURL *openURL = [NSURL URLWithString:app.h5URL ?: @""];
    if (!openURL) { return; }
    DAppBrowserViewController *vc = [[DAppBrowserViewController alloc] initWithDappURL:openURL];
    vc.title = app.name;
    vc.hidesBottomBarWhenPushed = true;
    [self.navigationController pushViewController:vc animated:YES];
}
- (void)createTableView{
    _tableView = [[UITableView alloc] init];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.separatorStyle = NO;
    _tableView.backgroundColor = UIColor.whiteColor;
    [self.view addSubview:_tableView];
    [_tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.right.bottom.mas_equalTo(0);
    }];
    [_tableView registerClass:[ExploreCell class] forCellReuseIdentifier:cellIdentity];
    
}
@end
