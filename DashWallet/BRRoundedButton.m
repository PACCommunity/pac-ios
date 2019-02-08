//
//  BRRoundedButton.m
//  pacwallet
//
//  Created by Alan Valencia on 1/15/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRRoundedButton.h"

@implementation BRRoundedButton

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
    
    if (self.contentHorizontalAlignment == UIControlContentHorizontalAlignmentLeft || self.contentHorizontalAlignment == UIControlContentHorizontalAlignmentRight) {
        //prevent text overlap
        self.titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
    }
    
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.5f;
}

@end
