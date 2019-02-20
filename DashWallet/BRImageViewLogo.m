//
//  BRImageViewLogo.m
//  pacwallet
//
//  Created by Alan Valencia on 1/15/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRImageViewLogo.h"

@implementation BRImageViewLogo

+ (instancetype) imageViewWithPACLogo {
    
    //initialize ImageView
    BRImageViewLogo *img = [[self alloc] initWithFrame:CGRectZero];
    img.contentMode = UIViewContentModeScaleAspectFit;
    
    //constraints
    img.translatesAutoresizingMaskIntoConstraints = false;
    [[img.widthAnchor constraintEqualToConstant:30] setActive:YES];
    [[img.heightAnchor constraintEqualToConstant:30] setActive:YES];
    
    //set image
    img.image = [UIImage imageNamed:@"PacLogo-small"];
    
    return  img;
}

@end
