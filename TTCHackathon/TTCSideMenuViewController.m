//
//  TTCSideMenuViewController.m
//  TTCHackathon
//
//  Created by DX181-XL on 2015-03-27.
//  Copyright (c) 2015 Pivotal. All rights reserved.
//

#import "TTCSideMenuViewController.h"
#import "UIViewController+RESideMenu.h"
#import <PCFAuth/PCFAuth.h>

@import PCFAppAnalytics;

@interface TTCSideMenuViewController ()

@property (strong, readwrite, nonatomic) UITableView *tableView;

@end

@implementation TTCSideMenuViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.tableView = ({
        UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, (self.view.frame.size.height - 54 * 5) / 2.0f, self.view.frame.size.width, 54 * 5) style:UITableViewStylePlain];
        tableView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleWidth;
        tableView.delegate = self;
        tableView.dataSource = self;
        tableView.opaque = NO;
        tableView.backgroundColor = [UIColor clearColor];
        tableView.backgroundView = nil;
        tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        tableView.bounces = NO;
        tableView.scrollsToTop = NO;
        tableView;
    });
    
    [self.view addSubview:self.tableView];
}

#pragma mark -
#pragma mark UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self routeToIndex:indexPath.row];
}

- (void)routeToIndex:(long)index {
    switch (index) {
        case 0:
            [self.sideMenuViewController setContentViewController:[[UINavigationController alloc] initWithRootViewController:[self.storyboard instantiateViewControllerWithIdentifier:@"TTCNotificationsTableViewController"]] animated:YES];
            [self.sideMenuViewController hideMenuViewController];
            [[PCFAppAnalytics shared] eventWithName:@"menuNotifications"];
            break;
        case 1:
            [self.sideMenuViewController setContentViewController:[[UINavigationController alloc] initWithRootViewController:[self.storyboard instantiateViewControllerWithIdentifier:@"TTCPreferencesTableViewController"]] animated:YES];
            [self.sideMenuViewController hideMenuViewController];
            [[PCFAppAnalytics shared] eventWithName:@"menuPreferences"];
            break;
        case 2:
            [self.sideMenuViewController setContentViewController:[[UINavigationController alloc] initWithRootViewController:[self.storyboard instantiateViewControllerWithIdentifier:@"TTCAboutViewController"]] animated:YES];
            [self.sideMenuViewController hideMenuViewController];
            [[PCFAppAnalytics shared] eventWithName:@"menuAbout"];
            break;
        case 3:
            [self.sideMenuViewController setContentViewController:[[UINavigationController alloc] initWithRootViewController:[self.storyboard instantiateViewControllerWithIdentifier:@"TTCPreferencesTableViewController"]] animated:YES];
            [self.sideMenuViewController hideMenuViewController];
            [[PCFAppAnalytics shared] eventWithName:@"logout"];
            [PCFAuth logout];
            break;
        default:
            break;
    }
}

#pragma mark -
#pragma mark UITableView Datasource

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 54;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
{
    return 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:21];
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.highlightedTextColor = [UIColor lightGrayColor];
        cell.selectedBackgroundView = [[UIView alloc] init];
    }
    
    NSArray *titles = @[@"Notifications", @"Preferences", @"About", @"Log Out"];
    cell.textLabel.text = titles[indexPath.row];
    
    return cell;
}

@end
