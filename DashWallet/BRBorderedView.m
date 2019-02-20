//
//  BRBorderedView.m
//  pacwallet
//
//  Created by Alan Valencia on 1/18/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRBorderedView.h"

@implementation BRBorderedView

- (void) awakeFromNib {
    [super awakeFromNib];
    [self configureProperties];
}

-(void) layoutSubviews {
    [super layoutSubviews];
    [self configureProperties];
}

- (void) setBorderColor:(UIColor *)borderColor {
    _borderColor = borderColor;
    [self configureProperties];
}

#pragma mark - Util methods

- (void) configureProperties {
    self.layer.borderColor = [self.borderColor CGColor];
    self.layer.borderWidth = self.borderWidth;
}

@end
