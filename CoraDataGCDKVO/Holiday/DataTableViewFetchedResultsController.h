//
//  DataTableViewFetchedResultsController.h
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-27.
//  Copyright (c) 2013年 Jack_team. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DataTableViewFetchedResultsController : UITableViewController <NSFetchedResultsControllerDelegate>
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@end
