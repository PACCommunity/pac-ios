//
//  BRHistoryTransactionCell.m
//  pacwallet
//
//  Created by Alan Valencia on 1/28/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRHistoryTransactionCell.h"
#import "BRTransaction.h"
#import "BRWalletManager.h"
#import "UIColor+Hexadecimal.h"
#import "BRTransaction+Date.h"

@implementation BRHistoryTransactionCell

+(NSString *) reuseCellId {
    return NSStringFromClass(self);
}

-(void) configureWithTxDates: (NSMutableDictionary *) txDates
                transactions: (NSArray *) transactions
                   indexPath: (NSIndexPath *) indexPath
                 blockHeight: (uint32_t) blockHeight {
    
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    
    BRTransaction *tx = transactions[indexPath.row];
    uint64_t received = [manager.wallet amountReceivedFromTransaction:tx],
    sent = [manager.wallet amountSentByTransaction:tx],
    balance = [manager.wallet balanceAfterTransaction:tx];
    uint32_t confirms = (tx.blockHeight > blockHeight) ? 0 : (blockHeight - tx.blockHeight) + 1;
    
#if SNAPSHOT
    received = [@[@(0), @(0), @(54000000), @(0), @(0), @(93000000)][indexPath.row] longLongValue];
    sent = [@[@(1010000), @(10010000), @(0), @(82990000), @(10010000), @(0)][indexPath.row] longLongValue];
    balance = [@[@(42980000), @(43990000), @(54000000), @(0), @(82990000), @(93000000)][indexPath.row]
               longLongValue];
    [txDates removeAllObjects];
    tx.timestamp = [NSDate timeIntervalSinceReferenceDate] - indexPath.row*100000;
    confirms = 6;
#endif
    
    self.textDescriptionLabel.textColor = [UIColor darkTextColor];
    self.sentLabel.hidden = YES;
    self.unconfirmedLabel.hidden = NO;
    self.detailDescriptionTextLabel.text = [tx dateForTx: txDates]; //[self dateForTx:tx];
    self.balanceLabel.attributedText = (manager.didAuthenticate) ? [manager attributedStringForPacAmount:balance withTintColor:self.balanceLabel.textColor pacSymbolSize:CGSizeMake(9, 9)] : nil;
    self.localBalanceLabel.text = (manager.didAuthenticate) ? [NSString stringWithFormat:@"(%@)", [manager localCurrencyStringForPacAmount:balance]] : nil;
    self.shapeshiftImageView.hidden = !tx.associatedShapeshift;
    
    if (confirms == 0 && ! [manager.wallet transactionIsValid:tx]) {
        self.unconfirmedLabel.text = NSLocalizedString(@"INVALID", nil);
        self.balanceLabel.text = self.localBalanceLabel.text = nil;
    }
    else if (confirms == 0 && [manager.wallet transactionIsPending:tx]) {
        self.unconfirmedLabel.text = NSLocalizedString(@"pending", nil);
        self.textDescriptionLabel.textColor = [UIColor grayColor];
        self.balanceLabel.text = self.localBalanceLabel.text = nil;
    }
    else if (confirms == 0 && ! [manager.wallet transactionIsVerified:tx]) {
        self.unconfirmedLabel.text = NSLocalizedString(@"unverified", nil);
    }
    else if (confirms < 6) {
        if (confirms == 0) self.unconfirmedLabel.text = NSLocalizedString(@"0 confirmations", nil);
        else if (confirms == 1) self.unconfirmedLabel.text = NSLocalizedString(@"1 confirmation", nil);
        else self.unconfirmedLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%d confirmations", nil),
                                      (int)confirms];
    }
    else {
        self.unconfirmedLabel.text = nil;
        self.unconfirmedLabel.hidden = YES;
        self.sentLabel.hidden = NO;
    }
    
    if (sent > 0 && received == sent) {
        self.textDescriptionLabel.attributedText = [manager attributedStringForPacAmount:sent];
        self.localCurrencyLabel.text = [NSString stringWithFormat:@"(%@)",
                                   [manager localCurrencyStringForPacAmount:sent]];
        self.sentLabel.text = NSLocalizedString(@"moved", nil);
        self.sentLabel.textColor = [UIColor whiteColor];
    }
    else if (sent > 0) {
        self.textDescriptionLabel.attributedText = [manager attributedStringForPacAmount:received - sent];
        self.localCurrencyLabel.text = [NSString stringWithFormat:@"(%@)",
                                   [manager localCurrencyStringForPacAmount:received - sent]];
        self.sentLabel.text = NSLocalizedString(@"sent", nil);
        self.sentLabel.textColor = [UIColor colorWithHexString:@"#FF2B2B"];
    }
    else {
        self.textDescriptionLabel.attributedText = [manager attributedStringForPacAmount:received];
        self.localCurrencyLabel.text = [NSString stringWithFormat:@"(%@)",
                                   [manager localCurrencyStringForPacAmount:received]];
        self.sentLabel.text = NSLocalizedString(@"received", nil);
        self.sentLabel.textColor = [UIColor colorWithHexString:@"#00D359"];
    }
    
}

@end
