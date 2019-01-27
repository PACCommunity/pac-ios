//
//  BRHistoryActionCell.m
//  pacwallet
//
//  Created by Alan Valencia on 1/27/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRHistoryActionCell.h"

@implementation BRHistoryActionCell

#pragma mark - Class Methods

+(NSString *) reuseCellId {
    return NSStringFromClass(self);
}

#pragma mark - Instance Methods

-(void) configureWithText: (NSString *) text image: (UIImage *) image {
    self.descriptionLabel.text = text;
    self.iconImageView.image = image;
}

@end
