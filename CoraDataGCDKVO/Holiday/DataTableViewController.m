//
//  DataTableViewController.m
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-27.
//  Copyright (c) 2013年 Jack_team. All rights reserved.
//

#import "DataTableViewController.h"
#import "SyncEngine.h"
#import "CoreDataController.h"
#import "Holiday.h"
#import "HolidayCell.h"
#import "UIImageView+AFNetworking.h"

@interface DataTableViewController ()
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation DataTableViewController

- (id)init {
    self = [super init];
    if (self) {
        self.datas = [NSMutableArray array];
        self.refreshControl = [[UIRefreshControl alloc] init];
        self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"下拉刷新"]; 
        [self.refreshControl addTarget:self action:@selector(loadDataFromCoreData) forControlEvents:UIControlEventValueChanged];
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
        [self.dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        [[SyncEngine sharedEngine] addObserver:self forKeyPath:@"syncInProgress" options:NSKeyValueObservingOptionNew context:nil];
        __weak typeof(self) weakSelf = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:@"SyncEngineSyncCompleted" object:nil queue:nil usingBlock:^(NSNotification *note) {
            [weakSelf loadDataFromCoreData];
            [weakSelf.refreshControl endRefreshing];
        }];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [[SyncEngine sharedEngine] registerNSManagedObjectClassToSync:[Holiday class]];
    self.title = @"利用CoreDta查询";
    self.view.backgroundColor = [UIColor whiteColor];
        
}

- (void)checkSyncStatus {
    // 这里只是检查下载和非下载状态，根据需求来定制需要的UI
    if ([[SyncEngine sharedEngine] syncInProgress]) {
        // 下载中
        NSLog(@"__FOUNTION__%@", @"checkSyncStatus");
    } else {

    }
}

- (void)loadDataFromCoreData {
    if (!_managedObjectContext) {
        self.managedObjectContext = [[CoreDataController sharedInstance] newManagedObjectContext];
    }
    
    [[[SyncEngine alloc] init] startSync];
    
    [self checkSyncStatus];
    
    [self.refreshControl beginRefreshing];
    
    //
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSArray *executeArray = nil;
        [weakSelf.managedObjectContext performBlockAndWait:^{
            [weakSelf.managedObjectContext reset];
            NSError *error = nil;
            NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Holiday"];
            [request setSortDescriptors:[NSArray arrayWithObject:
                                         [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
            [request setPredicate:[NSPredicate predicateWithFormat:@"syncStatus != %d", ObjectDeleted]];
            executeArray = [weakSelf.managedObjectContext executeFetchRequest:request error:&error];
            
            
            
        }];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.datas = executeArray;
            executeArray = nil;
            [weakSelf.tableView reloadData];
        });
    });
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.datas.count)
        [self loadDataFromCoreData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc {
    [[SyncEngine sharedEngine] removeObserver:self forKeyPath:@"syncInProgress" context:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"SyncEngineSyncCompleted" object:nil];
}

#pragma mark - UITableView delegate

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObject *date = [self.datas objectAtIndex:indexPath.row];
        [self.managedObjectContext performBlockAndWait:^{
            if ([[date valueForKey:@"objectId"] isEqualToString:@""] || [date valueForKey:@"objectId"] == nil) {
                [self.managedObjectContext deleteObject:date];
            } else {
                [date setValue:[NSNumber numberWithInt:ObjectDeleted] forKey:@"syncStatus"];
            }
            NSError *error = nil;
            BOOL saved = [self.managedObjectContext save:&error];
            if (!saved) {
                NSLog(@"Error saving main context: %@", error);
            } else {
                [[SyncEngine sharedEngine] startSync];
            }
            
            [[CoreDataController sharedInstance] saveMasterContext];
            [self loadDataFromCoreData];
            [self.tableView reloadData];
        }];
    }
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 257;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [self.datas count];
}

- (void)ConfigureCell:(id)cell atIndexPath:(NSIndexPath *)indexPath {
    HolidayCell *holidayCell = (HolidayCell *)cell;
    Holiday *holiday = [self.datas objectAtIndex:indexPath.row];
    holidayCell.nameLabel.text = holiday.name;
    holidayCell.dateLabel.text = [self.dateFormatter stringFromDate:holiday.date];
    holidayCell.detailsLabel.text = holiday.details;
    if (holiday.imageUrl) {
        [holidayCell.photoImageView setImageWithURL:[NSURL URLWithString:holiday.imageUrl] placeholderImage:[UIImage imageNamed:@"Default"]];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    HolidayCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        NSArray *nibs = [[NSBundle mainBundle] loadNibNamed:@"HolidayCell" owner:self options:nil];
        cell = [nibs lastObject];
    }
    // Configure the cell...
    [self ConfigureCell:cell atIndexPath:indexPath];
    
    
    return cell;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"syncInProgress"]) {
        [self checkSyncStatus];
    }
}

@end
