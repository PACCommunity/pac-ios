//
//  BRHistoryNoTxCell.h
//  pacwallet
//
//  Created by Alan Valencia on 1/27/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BRHistoryNoTxCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel *descriptionLabel;

+(NSString *) reuseCellId;
-(void) configureWithText: (NSString *) text;

@end
