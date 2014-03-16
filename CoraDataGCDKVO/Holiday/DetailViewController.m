//
//  DetailViewController.m
//  CoraDataGCDKVO
//
//  Created by 曾 宪华 on 13-8-27.
//  Copyright (c) 2013年 Jack_team. All rights reserved.
//

#import "DetailViewController.h"
#import "Holiday.h"
#import "UIImageView+AFNetworking.h"
#import "HolidayCell.h"

@interface DetailViewController ()
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation DetailViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
        [self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
    return 1;
}

- (void)ConfigureCell:(id)cell atIndexPath:(NSIndexPath *)indexPath {
    HolidayCell *holidayCell = (HolidayCell *)cell;
    Holiday *holiday = (Holiday *)self.managedObject;
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

@end
