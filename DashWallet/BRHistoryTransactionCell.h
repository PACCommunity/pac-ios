//
//  BRHistoryTransactionCell.h
//  pacwallet
//
//  Created by Alan Valencia on 1/28/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface BRHistoryTransactionCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel *textDescriptionLabel;
@property (nonatomic, weak) IBOutlet UILabel *detailDescriptionTextLabel;
@property (nonatomic, weak) IBOutlet UILabel *unconfirmedLabel;
@property (nonatomic, weak) IBOutlet UILabel *localCurrencyLabel;
@property (nonatomic, weak) IBOutlet UILabel *sentLabel;
@property (nonatomic, weak) IBOutlet UILabel *balanceLabel;
@property (nonatomic, weak) IBOutlet UILabel *localBalanceLabel;
@property (nonatomic, weak) IBOutlet UIImageView *shapeshiftImageView;

+(NSString *) reuseCellId;
-(void) configureWithTxDates: (NSMutableDictionary *) txDates
                transactions: (NSArray *) transactions
                   indexPath: (NSIndexPath *) indexPath
                 blockHeight: (uint32_t)blockHeight;


@end
