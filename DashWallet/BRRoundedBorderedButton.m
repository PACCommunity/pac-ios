//
//  BRRoundedBorderedButton.m
//  pacwallet
//
//  Created by Alan Valencia on 1/15/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRRoundedBorderedButton.h"

@implementation BRRoundedBorderedButton

#pragma mark - Util methods

- (void) configureProperties {
    
    [super configureProperties];
    
    self.layer.borderColor = [self.borderColor CGColor];
    self.layer.borderWidth = self.borderWidth;
}


@end
