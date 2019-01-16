//
//  BRPacNavigationController.m
//  pacwallet
//
//  Created by Alan Valencia on 1/16/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRPacNavigationController.h"

@interface BRPacNavigationController ()

@end

@implementation BRPacNavigationController

-(UIViewController*) childViewControllerForStatusBarStyle {
    return self.topViewController;
}

@end
