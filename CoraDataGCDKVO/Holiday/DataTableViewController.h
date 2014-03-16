//
//  DataTableViewController.h
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-27.
//  Copyright (c) 2013年 Jack_team. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DataTableViewController : UITableViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) NSArray *datas;
@end
