//
//  BRSemiRoundedButton.m
//  pacwallet
//
//  Created by Alan Valencia on 2/6/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRSemiRoundedButton.h"

@implementation BRSemiRoundedButton

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
    self.layer.cornerRadius = self.cornerRadius;
    self.clipsToBounds = true;
}

@end
