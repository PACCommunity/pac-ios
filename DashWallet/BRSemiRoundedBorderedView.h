//
//  BRSemiRoundedBorderedView.h
//  pacwallet
//
//  Created by Alan Valencia on 2/1/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BRSemiRoundedBorderedView : UIView

/** The width of the border.
 */
@property (nonatomic) IBInspectable CGFloat cornerRadius;

/** The color of the border.
 */
@property (strong, nonatomic) IBInspectable UIColor *borderColor;

/** The width of the border.
 */
@property (nonatomic) IBInspectable CGFloat borderWidth;

@end
