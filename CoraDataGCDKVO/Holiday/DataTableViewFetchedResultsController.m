//
//  DataTableViewFetchedResultsController.m
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-27.
//  Copyright (c) 2013年 Jack_team. All rights reserved.
//

#import "DataTableViewFetchedResultsController.h"
#import "SyncEngine.h"
#import "CoreDataController.h"
#import "Holiday.h"
#import "UIImageView+AFNetworking.h"
#import "HolidayCell.h"
#import "DetailViewController.h"

@interface DataTableViewFetchedResultsController () {
    NSInteger currentPage;
}
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation DataTableViewFetchedResultsController
- (id)init {
    self = [super init];
    if (self) {
        currentPage = 0;
        self.refreshControl = [[UIRefreshControl alloc] init];
        self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"下拉刷新"];
        [self.refreshControl addTarget:self action:@selector(loadDataFromCoreData) forControlEvents:UIControlEventValueChanged];
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
        [self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [[SyncEngine sharedEngine] addObserver:self forKeyPath:@"syncInProgress" options:NSKeyValueObservingOptionNew context:nil];
        __weak typeof(self) weakSelf = self;
        [[NSNotificationCenter defaultCenter] addObserverForName:@"SyncEngineSyncCompleted" object:nil queue:nil usingBlock:^(NSNotification *note) {
            currentPage = 0;
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
    self.title = @"利用NSFetchedResultsController";
    
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editing)];
    self.navigationItem.rightBarButtonItems = [NSArray arrayWithObjects:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addObject)], [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(loadDataFromCoreData)], nil];
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
    [[[SyncEngine alloc] init] startSync];
    
    self.managedObjectContext = [[CoreDataController sharedInstance] newManagedObjectContext];
    
    id sectionInfo = [[_fetchedResultsController sections] objectAtIndex:0];
    NSInteger total = [sectionInfo numberOfObjects];
    if (total < 60) {
        currentPage ++;
        __weak typeof(self) weakSelf = self;
        [self.refreshControl beginRefreshing];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error;
            if (![weakSelf.fetchedResultsController performFetch:&error]) {
                // Update to handle the error appropriately.
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                exit(-1);  // Fail
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf.tableView reloadData];
            });
        });
        
        
        [self checkSyncStatus];
    } else {
        NSLog(@"没有更多了");
    }
    
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!_fetchedResultsController.sections.count)
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

#pragma mark - NSFetchedResultsController

- (NSFetchedResultsController *)fetchedResultsController {
    
    if (_fetchedResultsController != nil) {
        [_fetchedResultsController.fetchRequest setFetchLimit:currentPage * 3];
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription
                                   entityForName:@"Holiday" inManagedObjectContext:_managedObjectContext];
    [fetchRequest setEntity:entity];
        
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:
                                 [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:NO]]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"syncStatus != %d", ObjectDeleted]];
    
    [fetchRequest setFetchLimit:currentPage * 3];
    
    NSFetchedResultsController *theFetchedResultsController =
    [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                        managedObjectContext:_managedObjectContext sectionNameKeyPath:nil
                                                   cacheName:nil];
    self.fetchedResultsController = theFetchedResultsController;
    _fetchedResultsController.delegate = self;
    
    return _fetchedResultsController;
    
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller is about to start sending change notifications, so prepare the table view for updates.
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationBottom];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self ConfigureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray
                                               arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:[NSArray
                                               arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id )sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller has sent all current change notifications, so tell the table view to process all updates.
    [self.tableView endUpdates];
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
    id sectionInfo = [[_fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (void)ConfigureCell:(id)cell atIndexPath:(NSIndexPath *)indexPath {
    HolidayCell *holidayCell = (HolidayCell *)cell;
    Holiday *holiday = [_fetchedResultsController objectAtIndexPath:indexPath];
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

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    // 这里是在编辑状态下触发的，比如+ -号   代表数据的添加和删除
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObject *date = [_fetchedResultsController objectAtIndexPath:indexPath];
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
        }];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        NSLog(@"添加");
    }
}

- (void)editing {
    [self.tableView setEditing:!self.tableView.editing animated:YES];
}

- (void)addObject {
    NSManagedObject *inserObject = [NSEntityDescription insertNewObjectForEntityForName:[[[_fetchedResultsController fetchRequest] entity] name] inManagedObjectContext:_fetchedResultsController.managedObjectContext];
    [inserObject setValue:@"Jack" forKey:@"name"];
    NSDate *date = [self dateSetToMidnightUsingDate:[NSDate date]];
    [inserObject setValue:date forKey:@"date"];
    [inserObject setValue:[NSNumber numberWithInt:ObjectCreated] forKey:@"syncStatus"];
    [inserObject setValue:@"hahah" forKey:@"details"];
    [inserObject setValue:@"oaoaoaoa" forKey:@"wikipediaLink"];
    [self.managedObjectContext performBlockAndWait:^{
        NSError *error = nil;
        BOOL saved = [self.managedObjectContext save:&error];
        if (!saved) {
            // do some real error handling
            NSLog(@"Could not save Date due to %@", error);
        }
        [[CoreDataController sharedInstance] saveMasterContext];
    }];
    
    [self loadDataFromCoreData];
}

- (NSDate *)dateSetToMidnightUsingDate:(NSDate *)aDate {
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [gregorian components:NSUIntegerMax fromDate:aDate];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    
    return [gregorian dateFromComponents: components];
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}



// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
    if (fromIndexPath == toIndexPath) {
        return;
    }
    NSManagedObject *fromObject = [_fetchedResultsController objectAtIndexPath:fromIndexPath];
    
    NSManagedObject *toObject = [_fetchedResultsController objectAtIndexPath:toIndexPath];
    
    [fromObject setValue:[NSNumber numberWithInteger:ObjectUpData] forKey:@"syncStatus"];
    [fromObject setValue:[toObject valueForKey:@"date"] forKey:@"date"];
    
    [toObject setValue:[NSNumber numberWithInteger:ObjectUpData] forKey:@"syncStatus"];
    [toObject setValue:[fromObject valueForKey:@"date"] forKey:@"date"];
    [self.managedObjectContext performBlockAndWait:^{
        NSError *error = nil;
        BOOL saved = [self.managedObjectContext save:&error];
        if (!saved) {
            // do some real error handling
            NSLog(@"Could not save Date due to %@", error);
        }
        [[CoreDataController sharedInstance] saveMasterContext];
    }];
    
    [self loadDataFromCoreData];
}



// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    
    DetailViewController *detailViewController = [[DetailViewController alloc] init];
    detailViewController.managedObject = [_fetchedResultsController objectAtIndexPath:indexPath];
    // ...
    // Pass the selected object to the new view controller.
    [self.navigationController pushViewController:detailViewController animated:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"syncInProgress"]) {
        [self checkSyncStatus];
    }
}

@end
