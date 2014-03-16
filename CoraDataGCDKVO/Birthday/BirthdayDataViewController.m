//
//  BirthdayDataViewController.m
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-27.
//  Copyright (c) 2013年 Jack_team. All rights reserved.
//

#import "BirthdayDataViewController.h"
#import "CoreDataController.h"
#import "SyncEngine.h"
#import "UIImageView+AFNetworking.h"
#import "Birthday.h"
#import "BirthdayCell.h"

@interface BirthdayDataViewController ()
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation BirthdayDataViewController


- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        self.refreshControl = [[UIRefreshControl alloc] init];
        self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"下拉刷新"]; 
        [self.refreshControl addTarget:self action:@selector(loadDataFromCoreData) forControlEvents:UIControlEventValueChanged];
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
        [self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        
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
    self.title = @"Birthday";
    [[SyncEngine sharedEngine] registerNSManagedObjectClassToSync:[Birthday class]];
    // Uncomment the following line to preserve selection between presentations.
    self.clearsSelectionOnViewWillAppear = NO;
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
    self.managedObjectContext = [[CoreDataController sharedInstance] newManagedObjectContext];
    
    [[[SyncEngine alloc] init] startSync];
    
    [self.refreshControl beginRefreshing];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        if (![weakSelf.fetchedResultsController performFetch:&error]) {
            // Update to handle the error appropriately.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            exit(-1);  // Fail
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.tableView reloadData];
        });
    });
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
    if (_fetchedResultsController) {
        return _fetchedResultsController;
    }
    
    // 创建查询条件，然后一级一级的往下查
    
    NSFetchRequest *fetchedRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Birthday" inManagedObjectContext:self.managedObjectContext];
    [fetchedRequest setEntity:entity];
    
    NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES];
    
    NSArray *sorDescriptors = [NSArray arrayWithObjects:sortDescriptor, nil];
    
    [fetchedRequest setSortDescriptors:sorDescriptors];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"syncStatus != %d", ObjectDeleted];
    
    [fetchedRequest setPredicate:predicate];
    
    [fetchedRequest setFetchBatchSize:3];
    
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchedRequest managedObjectContext:_managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    
    self.fetchedResultsController = fetchedResultsController;
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
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
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
    BirthdayCell *birthdayCell = (BirthdayCell *)cell;
    Birthday *birthday = [_fetchedResultsController objectAtIndexPath:indexPath];
    birthdayCell.nameLabel.text = birthday.name;
    birthdayCell.dateLabel.text = [self.dateFormatter stringFromDate:birthday.date];
    birthdayCell.detailsLabel.text = birthday.facebook;
    if (birthday.imageUrl) {
        [birthdayCell.photoImageView setImageWithURL:[NSURL URLWithString:birthday.imageUrl] placeholderImage:[UIImage imageNamed:@"Default"]];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    BirthdayCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        NSArray *nibs = [[NSBundle mainBundle] loadNibNamed:@"BirthdayCell" owner:self options:nil];
        cell = [nibs lastObject];
    }
    // Configure the cell...
    [self ConfigureCell:cell atIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here. Create and push another view controller.
    /*
     <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
     [self.navigationController pushViewController:detailViewController animated:YES];
     */
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"syncInProgress"]) {
        [self checkSyncStatus];
    }
}

@end
