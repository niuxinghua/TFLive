//
//  ViewController.m
//  TFLive
//
//  Created by wei shi on 2017/6/28.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "ViewController.h"
#import <AFNetworking.h>
#import "TFMoviePlayViewController.h"

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>{
    UITableView *_tableview;
    NSMutableArray *_liveDatas;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _liveDatas = [[NSMutableArray alloc] init];
    
    _tableview = [[UITableView alloc] initWithFrame:[UIScreen mainScreen].bounds style:(UITableViewStyleGrouped)];
    _tableview.delegate = self;
    _tableview.dataSource = self;
    [self.view addSubview:_tableview];
    
    [self requestData];
    
    //http://116.211.167.106/api/live/aggregation?uid=133825214&interest=1
}

-(void)requestData{
    AFHTTPSessionManager *sessionManager = [[AFHTTPSessionManager alloc] init];
    sessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/plain", nil];
    [sessionManager POST:@"http://116.211.167.106/api/live/aggregation?uid=133825214&interest=1" parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        NSLog(@"%@",responseObject);
        
        _liveDatas = [responseObject objectForKey:@"lives"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [_tableview reloadData];
        });
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"request live data failed!, %@",error);
    }];
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _liveDatas.count;
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:(UITableViewCellStyleDefault) reuseIdentifier:@"Cell"];
    }
    
    NSDictionary *liveData = [_liveDatas objectAtIndex:indexPath.row];
    cell.textLabel.text = [liveData objectForKey:@"name"];
    
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSDictionary *liveData = [_liveDatas objectAtIndex:indexPath.row];
    NSString *stream_addr = [liveData objectForKey:@"stream_addr"];
    
    TFMoviePlayViewController *movieVC = [[TFMoviePlayViewController alloc] init];
    movieVC.liveAddr = stream_addr;
    
    [self.navigationController pushViewController:movieVC animated:YES];
}

@end
