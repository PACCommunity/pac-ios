//
//  BRRoundedLabel.m
//  pacwallet
//
//  Created by Alan Valencia on 2/6/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRRoundedLabel.h"

@implementation BRRoundedLabel

- (void) awakeFromNib {
    [super awakeFromNib];
    [self configureProperties];
}

-(void) layoutSubviews {
    [super layoutSubviews];
    [self configureProperties];
}

#pragma mark - Util methods

- (void) configureProperties {
    
    CGFloat min = fmin(self.frame.size.width, self.frame.size.height);
    self.layer.cornerRadius = min/2;
    self.clipsToBounds = YES;
}

@end
