//
//  BRHistoryNoTxCell.m
//  pacwallet
//
//  Created by Alan Valencia on 1/27/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRHistoryNoTxCell.h"

@implementation BRHistoryNoTxCell

#pragma mark - Class Methods

+(NSString *) reuseCellId {
    return NSStringFromClass(self);
}

#pragma mark - Instance Methods

-(void) configureWithText: (NSString *) text {
    self.descriptionLabel.text = text;
}

@end
