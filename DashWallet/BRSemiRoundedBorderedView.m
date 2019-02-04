//
//  BRSemiRoundedBorderedView.m
//  pacwallet
//
//  Created by Alan Valencia on 2/1/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRSemiRoundedBorderedView.h"

@implementation BRSemiRoundedBorderedView

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
    self.layer.borderColor = [self.borderColor CGColor];
    self.layer.borderWidth = self.borderWidth;
    self.layer.cornerRadius = self.cornerRadius;
    self.clipsToBounds = true;
}

@end
