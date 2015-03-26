//
//  Copyright (c) 2014 Pivotal. All rights reserved.
//

#import <PCFData/PCFData.h>
#import <PCFAuth/PCFAuth.h>
#import "TTCPushRegistrationHelper.h"
#import "TTCNotificationsTableViewController.h"
#import "TTCLoadingOverlayView.h"
#import "TTCNotificationTableViewCell.h"
#import "TTCAppDelegate.h"
#import "TTCSettings.h"
#import "TTCLastNotificationView.h"
#import "TTCUserDefaults.h"

@interface TTCNotificationsTableViewController ()

@property PCFKeyValueObject *savedStopsAndRouteObject;
@property TTCLoadingOverlayView *loadingOverlayView;

@property (strong, nonatomic) NSMutableArray *stopAndRouteArray; // keeps track of all stops and routes we saved (enabled AND disabled).
@property TTCLastNotificationView *lastNotificationView;
@property UIRefreshControl *refreshControl;

@end

@implementation TTCNotificationsTableViewController

static NSString* const PCFCollection = @"notifications";
static NSString* const PCFKey = @"my-notifications";

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    self.savedStopsAndRouteObject = [PCFKeyValueObject objectWithCollection:PCFCollection key:PCFKey];

    self.tableView.alwaysBounceVertical = YES;
    [self.navigationController.navigationBar setBarTintColor:[UIColor redColor]];
    self.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName : [UIColor whiteColor]};
    self.navigationController.navigationBarHidden = NO;
    [self.navigationController.navigationBar setTranslucent:YES];

    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.tableView addSubview:self.refreshControl];

    [self.refreshControl addTarget:self action:@selector(refreshTable) forControlEvents:UIControlEventValueChanged];

    self.stopAndRouteArray = [NSMutableArray array];
}

- (void) refreshTable
{
    [self showLastNotification];
    [self fetchRoutesAndStops];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:NO];
    [self.tableView reloadData];
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:NO];
    [self registerForNotifications];
    [self showLastNotification];

    [self fetchRoutesAndStops];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kRemoteNotificationReceived object:nil];
}

#pragma mark - Notification handling

- (void) registerForNotifications {
    void (^block)(NSNotification*) = ^(NSNotification* notification) {
        [self showLastNotification];
        [self.lastNotificationView flash];
    };
    [[NSNotificationCenter defaultCenter] addObserverForName:kRemoteNotificationReceived
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:block];
}

- (void) showLastNotification {
    NSString *lastNotificationText = [TTCUserDefaults getLastNotificationText];
    NSDate *lastNotificationDate = [TTCUserDefaults getLastNotificationTime];
    if (lastNotificationText) {
        
        NSArray *objects = [[NSBundle mainBundle] loadNibNamed:@"TTCLastNotificationView" owner:self options:nil];
        for (id i in objects) {
            if([i isKindOfClass:[TTCLastNotificationView class]]) {
                self.lastNotificationView = (TTCLastNotificationView*) i;
                [self.lastNotificationView showNotification:lastNotificationText date:lastNotificationDate];
                [self.tableView reloadData];
            }
        }
    } else {
        self.lastNotificationView = nil;
        [self.tableView reloadData];
    }
}

#pragma mark - Table view data source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return self.lastNotificationView != nil ? 1 : 0;
    } else {
        return self.stopAndRouteArray.count;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        return 96;
    } else {
        return 127;
    }
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"keyValueCell";
 
    if (indexPath.section == 0) {
        return self.lastNotificationView;
    }
    
    TTCNotificationTableViewCell *cell = (TTCNotificationTableViewCell*) [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    TTCStopAndRouteInfo* currentItem = [self.stopAndRouteArray objectAtIndex:indexPath.row];
    
    if (currentItem) {
        [cell populateViews:currentItem tag:indexPath.row];
        [cell.toggleSwitch addTarget:self action:@selector(switchToggled:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    return cell;
}

- (BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        if (editingStyle == UITableViewCellEditingStyleDelete) {
            [TTCUserDefaults setLastNotificationText:nil];
            [TTCUserDefaults setLastNotificationTime:nil];
            [self showLastNotification];
        }
    } else {
        if (editingStyle == UITableViewCellEditingStyleDelete) {
            TTCStopAndRouteInfo* currentItem = [self.stopAndRouteArray objectAtIndex:indexPath.row];
            if (!currentItem) return;
            
            // delete from array
            [self.stopAndRouteArray removeObjectAtIndex:indexPath.row];

            // delete from set
            [TTCPushRegistrationHelper updateTags:[self enabledTags]];
            
            [self persistDataToRemoteStore];
            
            // need to refresh the table to update the view
            [self.tableView reloadData];
            NSLog(@"Deleted row.");
            self.tableView.alwaysBounceVertical = YES;
        }
    }
}

#pragma mark - segue functions

// When we click the done button in the scheduler view we UNWIND back to here.
- (IBAction) unwindToSavedTableView:(UIStoryboardSegue *)sender
{
    [self persistDataToRemoteStore];
    [TTCPushRegistrationHelper updateTags:[self enabledTags]];
}

#pragma mark - Action events

- (void) switchToggled:(UISwitch*)mySwitch
{
    TTCStopAndRouteInfo* currentItem = [self.stopAndRouteArray objectAtIndex:mySwitch.tag];
    currentItem.enabled = [mySwitch isOn];
    
    [TTCPushRegistrationHelper updateTags:[self enabledTags]];

    [self persistDataToRemoteStore];
}

- (IBAction) logout
{
    self.stopAndRouteArray = [NSMutableArray array];
    [PCFAuth invalidateToken];
    [self fetchRoutesAndStops];    
}

#pragma mark - Array and dictionary functions

- (void) addToStopAndRoute:(TTCStopAndRouteInfo *)stopAndRouteObject // add to our array
{
    for (TTCStopAndRouteInfo* stopAndRouteInfo in self.stopAndRouteArray) {
        if([stopAndRouteInfo.stop isEqualToString:stopAndRouteObject.stop] && [stopAndRouteInfo.time isEqualToString:stopAndRouteObject.time]) {
            NSLog(@"Not adding new stop since it's already in the list.");
            return;
        }
    }
    [self.stopAndRouteArray addObject:stopAndRouteObject];
}

#pragma mark - MSSDataObject server functions

/* When we authenticate we have to fetch our routes and stop from the server */
- (void) fetchRoutesAndStops
{    
    NSLog(@"Fetching saved routes and stops...");
    
    [self.savedStopsAndRouteObject getWithCompletionBlock:^(PCFDataResponse *response) {
        
        if (response.error == nil) {
            PCFKeyValue *keyValue = (PCFKeyValue *)response.object;
            
            NSData* data = [keyValue.value dataUsingEncoding:NSUTF8StringEncoding];
            NSArray* jsonArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            
            if (self.stopAndRouteArray) {
                [self.stopAndRouteArray removeAllObjects];
            }
            
            if (!jsonArray || jsonArray.count <= 0) {
                NSLog(@"Note: no routes and stops saved on server.");
            } else {
            
                for (int i = 0; i < jsonArray.count; ++i) {
                    NSDictionary *dictionary = [jsonArray objectAtIndex:i];
                    TTCStopAndRouteInfo *obj = [[TTCStopAndRouteInfo alloc] initWithDictionary:dictionary];

                    [self.stopAndRouteArray addObject:obj];
                    
                    NSLog(@"Loaded item: %@", dictionary);
                }
            }
            
            [[NSNotificationCenter defaultCenter] removeObserver:self];
            [self.loadingOverlayView removeFromSuperview];
            [self.tableView reloadData];

            // Update the push registration on the server
            [TTCPushRegistrationHelper updateTags:[self enabledTags]];
            
            if (self.refreshControl && [self.refreshControl isRefreshing]) {
                [self.refreshControl endRefreshing];
            }
            
        } else {
            NSLog(@"Error: could not fetch saved route and stops: %@", response.error);
            [self.loadingOverlayView removeFromSuperview];

            if (self.refreshControl && [self.refreshControl isRefreshing]) {
                [self.refreshControl endRefreshing];
            }
        }
        
    }] ;
}

/* Everytime we change anything in our ARRAY, we have to push it up to the server */
- (void) persistDataToRemoteStore
{
    NSLog(@"Pushing saved stops to server here...");
    NSMutableArray *stopAndRouteListArray = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < self.stopAndRouteArray.count; i++) {
        TTCStopAndRouteInfo *stopAndRouteElement = [self.stopAndRouteArray objectAtIndex:i];
        [stopAndRouteListArray addObject:[stopAndRouteElement formattedDictionary]];
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:stopAndRouteListArray options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    NSLog(@"Saving routesAndStops: %@", jsonString);
    
    [self.savedStopsAndRouteObject putWithValue:jsonString completionBlock:^(PCFDataResponse *response) {
        if (response.error != nil) {
            NSLog(@"saving to datasync successful");
        } else {
            NSLog(@"saving to datasync failed: %@", response.error);
        }
    }];
}

- (NSSet *) enabledTags {
    NSMutableSet *mutableSet = [NSMutableSet set];
    
    for (TTCStopAndRouteInfo *stopAndRouteInfo in self.stopAndRouteArray) {
        if (stopAndRouteInfo.enabled) {
            [mutableSet addObject:stopAndRouteInfo.tag];
        }
    }
    
    return mutableSet;
}

@end
