//
//  BRDataDefaultsHandler.m
//  pacwallet
//
//  Created by Alan Valencia on 2/20/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRDataDefaultsHandler.h"
#import "BRUserDefaultsConstants.h"
#import "BRPeerManager.h"

@implementation BRDataDefaultsHandler
    
+(BOOL) isFirstLaunch {
    
    NSString *value = [[NSUserDefaults standardUserDefaults] valueForKey:FIRST_LAUNCH_KEY];
    
    if(value == nil) {
        
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:FIRST_LAUNCH_KEY];
        
        return YES;
    } else {
        return NO;
    }
}
    
+(void) updateTrustedPeerFirstLaunch {
    
    BOOL isFirstLaunch = [BRDataDefaultsHandler isFirstLaunch];
    NSString *trustedPeer = [[NSUserDefaults standardUserDefaults] valueForKey:SETTINGS_FIXED_PEER_KEY];

    if(isFirstLaunch && trustedPeer == nil) {
        
        NSArray *ipsArray = @[@"209.250.251.184", @"108.61.252.138", @"144.202.48.162", @"144.202.101.191"];
        uint32_t randomIndex = arc4random_uniform([ipsArray count]);
        NSString *fixedPeer = ipsArray[randomIndex];
        
        [[BRPeerManager sharedInstance] updateTrustedPeer:fixedPeer includingReconnection:YES];
    }
}
    
@end
