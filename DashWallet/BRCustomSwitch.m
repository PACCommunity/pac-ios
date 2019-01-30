//
//  BRCustomSwitch.m
//  pacwallet
//
//  Created by Alan Valencia on 1/30/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRCustomSwitch.h"

@implementation BRCustomSwitch

@dynamic offTint;
-(void) setOffTint:(UIColor *)offTint {
    self.tintColor = offTint;
    
    self.backgroundColor = offTint;
}

-(void) layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = self.bounds.size.height/2;
}

@end
