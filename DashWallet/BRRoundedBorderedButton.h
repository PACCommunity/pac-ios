//
//  BRRoundedBorderedButton.h
//  pacwallet
//
//  Created by Alan Valencia on 1/15/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BRRoundedButton.h"

@interface BRRoundedBorderedButton : BRRoundedButton

/** The color of the border.
 */
@property (strong, nonatomic) IBInspectable UIColor *borderColor;

/** The width of the border.
 */
@property (nonatomic) IBInspectable CGFloat borderWidth;

@end
