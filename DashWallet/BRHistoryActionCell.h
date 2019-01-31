//
//  BRHistoryActionCell.h
//  pacwallet
//
//  Created by Alan Valencia on 1/27/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BRHistoryActionCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel *descriptionLabel;
@property (nonatomic, weak) IBOutlet UIImageView *iconImageView;

+(NSString *) reuseCellId;
-(void) configureWithText: (NSString *) text image: (UIImage *) image;

@end
