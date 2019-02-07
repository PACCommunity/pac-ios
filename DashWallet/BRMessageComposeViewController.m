//
//  BRMessageComposeViewController.m
//  pacwallet
//
//  Created by Alan Valencia on 2/6/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRMessageComposeViewController.h"

@interface BRMessageComposeViewController ()

@end

@implementation BRMessageComposeViewController

#pragma mark - View life cycle

-(void) viewDidLoad {
    [super viewDidLoad];
    
    self.navigationBar.tintColor = UIColor.whiteColor;
}

#pragma mark - Status Bar

- (UIStatusBarStyle) preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (UIViewController *) childViewControllerForStatusBarStyle {
    return nil;
}

@end
