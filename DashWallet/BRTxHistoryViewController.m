//
//  BRTxHistoryViewController.m
//  BreadWallet
//
//  Created by Aaron Voisine on 6/11/13.
//  Copyright (c) 2013 Aaron Voisine <voisine@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "BRTxHistoryViewController.h"
#import "BRRootViewController.h"
#import "BRSettingsViewController.h"
#import "BRTxDetailViewController.h"
#import "BRSeedViewController.h"
#import "BRWalletManager.h"
#import "BRPeerManager.h"
#import "BRTransaction.h"
#import "NSString+Bitcoin.h"
#import "NSData+Bitcoin.h"
#import "UIImage+Utils.h"
#import "BREventConfirmView.h"
#import "BREventManager.h"
#import "NSString+Pac.h"
#import <WebKit/WebKit.h>
#import "BRHistoryActionCell.h"
#import "BRHistoryNoTxCell.h"
#import "BRTransaction+Date.h"
#import "BRHistoryTransactionCell.h"

#define TRANSACTION_CELL_HEIGHT 75

@interface BRTxHistoryViewController ()

@property (nonatomic, strong) IBOutlet UIBarButtonItem *lock;
@property (nonatomic, strong) IBOutlet UIView *logoView;

@property (nonatomic, strong) NSArray *transactions;
@property (nonatomic, assign) BOOL moreTx;
@property (nonatomic, strong) NSMutableDictionary *txDates;
@property (nonatomic, strong) id backgroundObserver, balanceObserver, txStatusObserver;
@property (nonatomic, strong) id syncStartedObserver, syncFinishedObserver, syncFailedObserver;

@end

@implementation BRTxHistoryViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.txDates = [NSMutableDictionary dictionary];
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.navigationController.delegate = self;
    self.moreTx = YES;
}

-(UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    BRWalletManager *manager = [BRWalletManager sharedInstance];
    
#if SNAPSHOT
    BRTransaction *tx = [[BRTransaction alloc] initWithInputHashes:@[uint256_obj(UINT256_ZERO)] inputIndexes:@[@(0)]
                         inputScripts:@[[NSData data]] outputAddresses:@[@""] outputAmounts:@[@(0)]];
    
    manager.localCurrencyCode = [[NSLocale currentLocale] objectForKey:NSLocaleCurrencyCode];
    self.tableView.showsVerticalScrollIndicator = NO;
    self.moreTx = YES;
    manager.didAuthenticate = YES;
    [self unlock:nil];
    tx.txHash = UINT256_ZERO;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        self.transactions = @[tx, tx, tx, tx, tx, tx];
        [self.tableView reloadData];
        self.navigationItem.title = [NSString stringWithFormat:@"%@ (%@)", [manager stringForPacAmount:42980000],
                                     [manager localCurrencyStringForPacAmount:42980000]];
    });

    return;
#endif

    if (! manager.didAuthenticate) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            self.transactions = manager.wallet.allTransactions;
           
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        });
    }
    else [self unlock:nil];

    if (! self.backgroundObserver) {
        self.backgroundObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
            object:nil queue:nil usingBlock:^(NSNotification *note) {
                self.moreTx = YES;
                self.transactions = manager.wallet.allTransactions;
                [self.tableView reloadData];
                self.navigationItem.titleView = self.logoView;
                self.navigationItem.rightBarButtonItem = self.lock;
            }];
    }

    if (! self.balanceObserver) {
        self.balanceObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:BRWalletBalanceChangedNotification object:nil
            queue:nil usingBlock:^(NSNotification *note) {
                BRTransaction *tx = self.transactions.firstObject;

                self.transactions = manager.wallet.allTransactions;

                if (! [self.navigationItem.title isEqual:NSLocalizedString(@"Syncing:", nil)]) {
                    if (! manager.didAuthenticate) self.navigationItem.titleView = self.logoView;
                    else [self updateTitleView];
                }

                if (self.transactions.firstObject != tx) {
                    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                     withRowAnimation:UITableViewRowAnimationAutomatic];
                }
                else [self.tableView reloadData];
            }];
    }

    if (! self.txStatusObserver) {
        self.txStatusObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:BRPeerManagerTxStatusNotification object:nil
            queue:nil usingBlock:^(NSNotification *note) {
                self.transactions = manager.wallet.allTransactions;
                [self.tableView reloadData];
            }];
    }
    
    if (! self.syncStartedObserver) {
        self.syncStartedObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:BRPeerManagerSyncStartedNotification object:nil
            queue:nil usingBlock:^(NSNotification *note) {
                if ([[BRPeerManager sharedInstance]
                     timestampForBlockHeight:[BRPeerManager sharedInstance].lastBlockHeight] + WEEK_TIME_INTERVAL <
                    [NSDate timeIntervalSinceReferenceDate] &&
                    manager.seedCreationTime + DAY_TIME_INTERVAL < [NSDate timeIntervalSinceReferenceDate]) {
                    self.navigationItem.titleView = nil;
                    self.navigationItem.title = NSLocalizedString(@"Syncing:", nil);
                }
            }];
    }
    
    if (! self.syncFinishedObserver) {
        self.syncFinishedObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:BRPeerManagerSyncFinishedNotification object:nil
            queue:nil usingBlock:^(NSNotification *note) {
                if (! manager.didAuthenticate) self.navigationItem.titleView = self.logoView;
                else [self updateTitleView];
            }];
    }
    
    if (! self.syncFailedObserver) {
        self.syncFailedObserver =
            [[NSNotificationCenter defaultCenter] addObserverForName:BRPeerManagerSyncFailedNotification object:nil
            queue:nil usingBlock:^(NSNotification *note) {
                if (! manager.didAuthenticate) self.navigationItem.titleView = self.logoView;
                [self updateTitleView];
            }];
    }
}


-(UILabel*)titleLabel {
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    UILabel * titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 1, 100)];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    [titleLabel setBackgroundColor:[UIColor clearColor]];
    NSMutableAttributedString * attributedPacString = [[manager attributedStringForPacAmount:manager.wallet.balance withTintColor:[UIColor whiteColor]] mutableCopy];
    NSString * titleString = [NSString stringWithFormat:@" (%@)",
                              [manager localCurrencyStringForPacAmount:manager.wallet.balance]];
    [attributedPacString appendAttributedString:[[NSAttributedString alloc] initWithString:titleString attributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}]];
    titleLabel.attributedText = attributedPacString;
    return titleLabel;
}

-(void)updateTitleView {
    if (self.navigationItem.titleView && [self.navigationItem.titleView isKindOfClass:[UILabel class]]) {
        BRWalletManager *manager = [BRWalletManager sharedInstance];
        NSMutableAttributedString * attributedPacString = [[manager attributedStringForPacAmount:manager.wallet.balance withTintColor:[UIColor whiteColor]] mutableCopy];
        NSString * titleString = [NSString stringWithFormat:@" (%@)",
                                  [manager localCurrencyStringForPacAmount:manager.wallet.balance]];
        [attributedPacString appendAttributedString:[[NSAttributedString alloc] initWithString:titleString attributes:@{NSForegroundColorAttributeName:[UIColor whiteColor]}]];
        ((UILabel*)self.navigationItem.titleView).attributedText = attributedPacString;
        [((UILabel*)self.navigationItem.titleView) sizeToFit];
    } else {
        self.navigationItem.titleView = [self titleLabel];
    }
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (self.isMovingFromParentViewController || self.navigationController.isBeingDismissed) {
        //BUG: XXX this isn't triggered from start/recover new wallet
        if (self.backgroundObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.backgroundObserver];
        self.backgroundObserver = nil;
        if (self.balanceObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.balanceObserver];
        self.balanceObserver = nil;
        if (self.txStatusObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
        self.txStatusObserver = nil;
        if (self.syncStartedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncStartedObserver];
        self.syncStartedObserver = nil;
        if (self.syncFinishedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncFinishedObserver];
        self.syncFinishedObserver = nil;
        if (self.syncFailedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncFailedObserver];
        self.syncFailedObserver = nil;

        //self.buyController = nil;
    }

    [super viewWillDisappear:animated];
}

- (void)dealloc
{
    if (self.navigationController.delegate == self) self.navigationController.delegate = nil;
    if (self.backgroundObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.backgroundObserver];
    if (self.balanceObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.balanceObserver];
    if (self.txStatusObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.txStatusObserver];
    if (self.syncStartedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncStartedObserver];
    if (self.syncFinishedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncFinishedObserver];
    if (self.syncFailedObserver) [[NSNotificationCenter defaultCenter] removeObserver:self.syncFailedObserver];
}

- (uint32_t)blockHeight
{
    static uint32_t height = 0;
    uint32_t h = [BRPeerManager sharedInstance].lastBlockHeight;
    
    if (h > height) height = h;
    return height;
}

- (void)setTransactions:(NSArray *)transactions
{
    uint32_t height = self.blockHeight;

    if (! [BRWalletManager sharedInstance].didAuthenticate &&
        [self.navigationItem.title isEqual:NSLocalizedString(@"Syncing:", nil)]) {
        _transactions = @[];
        if (transactions.count > 0) self.moreTx = YES;
    }
    else {
        if (transactions.count <= 5) self.moreTx = NO;
        _transactions = (self.moreTx) ? [transactions subarrayWithRange:NSMakeRange(0, 5)] : [transactions copy];
    
        if (! [BRWalletManager sharedInstance].didAuthenticate) {
            for (BRTransaction *tx in _transactions) {
                if (tx.blockHeight == TX_UNCONFIRMED ||
                    (tx.blockHeight > height - 5 && tx.blockHeight <= height)) continue;
                _transactions = [_transactions subarrayWithRange:NSMakeRange(0, [_transactions indexOfObject:tx])];
                self.moreTx = YES;
                break;
            }
        }
    }
}

- (void)setBackgroundForCell:(UITableViewCell *)cell tableView:(UITableView *)tableView indexPath:(NSIndexPath *)path
{    
    [cell viewWithTag:100].hidden = (path.row > 0);
    [cell viewWithTag:101].hidden = (path.row + 1 < [self tableView:tableView numberOfRowsInSection:path.section]);
    
    UIView *bgColorView = [[UIView alloc] init];
    bgColorView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
    [cell setSelectedBackgroundView:bgColorView];
}

// MARK: - IBAction

- (IBAction)done:(id)sender
{
    [BREventManager saveEvent:@"tx_history:dismiss"];
    [self.navigationController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)unlock:(id)sender
{
    BRWalletManager *manager = [BRWalletManager sharedInstance];

    if (sender) [BREventManager saveEvent:@"tx_history:unlock"];
    if (! manager.didAuthenticate) {
        [manager authenticateWithPrompt:nil andTouchId:YES alertIfLockout:YES completion:^(BOOL authenticated, BOOL cancelled) {
            if (authenticated) {
                if (sender) [BREventManager saveEvent:@"tx_history:unlock_success"];
                
                [self updateTitleView];
                [self.navigationItem setRightBarButtonItem:nil animated:(sender) ? YES : NO];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    self.transactions = manager.wallet.allTransactions;
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (sender && self.transactions.count > 0) {
                            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:0]
                                          withRowAnimation:UITableViewRowAnimationAutomatic];
                        }
                        else [self.tableView reloadData];
                    });
                });
            }
        }];
    }
}

- (IBAction)scanQR:(id)sender
{
    //TODO: show scanner in settings rather than dismissing
    [BREventManager saveEvent:@"tx_history:scan_qr"];
    UINavigationController *nav = (id)self.navigationController.presentingViewController;

    nav.view.alpha = 0.0;

    [nav dismissViewControllerAnimated:NO completion:^{
        [(id)((BRRootViewController *)nav.viewControllers.firstObject).sendViewController scanQR:nil];
        [UIView animateWithDuration:0.1 delay:1.5 options:0 animations:^{ nav.view.alpha = 1.0; } completion:nil];
    }];
}

- (IBAction)showTx:(id)sender
{
    [BREventManager saveEvent:@"tx_history:show_tx"];
    BRTxDetailViewController *detailController
        = [self.storyboard instantiateViewControllerWithIdentifier:@"TxDetailViewController"];
    detailController.transaction = sender;
    detailController.txDateString = [sender dateForTx: self.txDates];
    [self.navigationController pushViewController:detailController animated:YES];
}

- (IBAction)more:(id)sender
{
    [BREventManager saveEvent:@"tx_history:more"];
    BRWalletManager *manager = [BRWalletManager sharedInstance];
    NSUInteger txCount = self.transactions.count;
    
    if (! manager.didAuthenticate) {
        [self unlock:sender];
        return;
    }
    
    [self.tableView beginUpdates];
    [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:txCount inSection:0]]
     withRowAnimation:UITableViewRowAnimationFade];
    self.moreTx = NO;
    self.transactions = manager.wallet.allTransactions;
    
    NSMutableArray *transactions = [NSMutableArray arrayWithCapacity:self.transactions.count];
    
    while (txCount == 0 || txCount < self.transactions.count) {
        [transactions addObject:[NSIndexPath indexPathForRow:txCount++ inSection:0]];
    }
    
    [self.tableView insertRowsAtIndexPaths:transactions withRowAnimation:UITableViewRowAnimationTop];
    [self.tableView endUpdates];
}

//- (void)showBuyAlert
//{
//    // grab a blurred image for the background
//    UIGraphicsBeginImageContext(self.navigationController.view.bounds.size);
//    [self.navigationController.view drawViewHierarchyInRect:self.navigationController.view.bounds
//                                         afterScreenUpdates:NO];
//    UIImage *bgImg = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//    UIImage *blurredBgImg = [bgImg blurWithRadius:3];
//
//    // display the popup
//    __weak BREventConfirmView *view =
//        [[NSBundle mainBundle] loadNibNamed:@"BREventConfirmView" owner:nil options:nil][0];
//    view.titleLabel.text = NSLocalizedString(@"Buy $PAC in pacwallet!", nil);
//    view.descriptionLabel.text =
//        NSLocalizedString(@"You can now buy $PAC in\npacwallet with cash or\nbank transfer.", nil);
//    [view.okBtn setTitle:NSLocalizedString(@"Try It!", nil) forState:UIControlStateNormal];
//
//    view.image = blurredBgImg;
//    view.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
//    view.frame = self.navigationController.view.bounds;
//    view.alpha = 0;
//    [self.navigationController.view addSubview:view];
//
//    [UIView animateWithDuration:.5 animations:^{
//        view.alpha = 1;
//    }];
//
//    view.completionHandler = ^(BOOL didApprove) {
//        if (didApprove) [self showBuy];
//
//        [UIView animateWithDuration:.5 animations:^{
//            view.alpha = 0;
//        } completion:^(BOOL finished) {
//            [view removeFromSuperview];
//        }];
//    };
//}

// MARK: - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    bool buyEnabled = FALSE;
    switch (section) {
        case 0:
            if (self.transactions.count == 0) return 1;
            return (self.moreTx) ? self.transactions.count + 1 : self.transactions.count;

        case 1:
            return (buyEnabled ? 3 : 2);
    }

    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *noTxIdent = @"NoTxCell", *moreCellIden = @"MoreCell";
    UITableViewCell *cell = nil;

    switch (indexPath.section) {
        case 0:
            if (self.moreTx && indexPath.row >= self.transactions.count) {
                
                if(indexPath.row > 0) {
                    cell = [tableView dequeueReusableCellWithIdentifier:moreCellIden];
                    cell.textLabel.text = NSLocalizedString(@"more...", nil);
                } else {
                    cell = [tableView dequeueReusableCellWithIdentifier:noTxIdent];
                    BRHistoryNoTxCell *noTxCell = (BRHistoryNoTxCell *)cell;
                    [noTxCell configureWithText:NSLocalizedString(@"transaction history", nil)];
                }

            }
            else if (self.transactions.count > 0) {
                
                cell = [tableView dequeueReusableCellWithIdentifier: [BRHistoryTransactionCell reuseCellId]];
                BRHistoryTransactionCell *transactionCell = (BRHistoryTransactionCell *)cell;
                
                [transactionCell configureWithTxDates:self.txDates transactions:self.transactions indexPath:indexPath blockHeight: self.blockHeight];
            }
            else {
                cell = [tableView dequeueReusableCellWithIdentifier:noTxIdent];
                
                BRHistoryNoTxCell *noTxtCell = (BRHistoryNoTxCell *)cell;
                [noTxtCell configureWithText:NSLocalizedString(@"no transactions", nil)];
            }

            break;

        case 1:
            
            cell = [tableView dequeueReusableCellWithIdentifier: [BRHistoryActionCell reuseCellId]];
            BRHistoryActionCell *actionCell = (BRHistoryActionCell *)cell;
            
            bool buyEnabled = FALSE;
            long adjustedRow = !buyEnabled ? indexPath.row + 1 : indexPath.row;
            switch (adjustedRow) {
                case 0:
                    
                    [actionCell configureWithText:NSLocalizedString(@"Buy $PAC", nil) image:[UIImage imageNamed:@"dash-buy-blue-small"]];
                    break;
                    
                case 1:
                    
                    [actionCell configureWithText:NSLocalizedString(@"import private key", nil) image:[UIImage imageNamed:@"scnicngray"]];
                    break;

                case 2:
                    
                    [actionCell configureWithText:NSLocalizedString(@"settings", nil) image:[UIImage imageNamed:@"settingsIcn"]];
                    break;
            }
            
            break;
    }
    
    [self setBackgroundForCell:cell tableView:tableView indexPath:indexPath];
    return cell;
}

// MARK: - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0: return (self.moreTx && indexPath.row >= self.transactions.count) ? 44.0 : TRANSACTION_CELL_HEIGHT;
        case 1: return TRANSACTION_CELL_HEIGHT;
    }
    
    return 44.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSString *sectionTitle = [self tableView:tableView titleForHeaderInSection:section];

    if (sectionTitle.length == 0) return 22.0;

    CGRect r = [sectionTitle boundingRectWithSize:CGSizeMake(self.view.frame.size.width - 20.0, CGFLOAT_MAX)
                options:NSStringDrawingUsesLineFragmentOrigin
                attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:13]} context:nil];
    
    return r.size.height + 22.0 + 10.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width,
                                                         [self tableView:tableView heightForHeaderInSection:section])];
    UILabel *l = [UILabel new];
    CGRect r = CGRectMake(15.0, 0.0, v.frame.size.width - 20.0, v.frame.size.height - 22.0);
    
    l.text = [self tableView:tableView titleForHeaderInSection:section];
    l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont systemFontOfSize:13];
    l.textColor = [UIColor grayColor];
    l.shadowColor = [UIColor whiteColor];
    l.shadowOffset = CGSizeMake(0.0, 1.0);
    l.numberOfLines = 0;
    r.size.width = [l sizeThatFits:r.size].width;
    r.origin.x = (self.view.frame.size.width - r.size.width)/2;
    if (r.origin.x < 15.0) r.origin.x = 15.0;
    l.frame = r;
    v.backgroundColor = [UIColor clearColor];
    [v addSubview:l];

    return v;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return (section + 1 == [self numberOfSectionsInTableView:tableView]) ? 22.0 : 0.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width,
                                                         [self tableView:tableView heightForFooterInSection:section])];
    v.backgroundColor = [UIColor clearColor];
    return v;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    //TODO: include an option to generate a new wallet and sweep old balance if backup may have been compromized
    UIViewController *destinationController = nil;

    switch (indexPath.section) {
        case 0: // transaction
            if (self.moreTx && indexPath.row >= self.transactions.count) { // more...
                [self performSelector:@selector(more:) withObject:tableView afterDelay:0.0];
            }
            else if (self.transactions.count > 0) [self showTx:self.transactions[indexPath.row]]; // transaction details

            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            break;

        case 1:
        {
            bool buyEnabled = FALSE;//[[BRAPIClient sharedClient] featureEnabled:BRFeatureFlagsBuyPac];
            long adjustedRow = !buyEnabled ? indexPath.row + 1 : indexPath.row;
            switch (adjustedRow) {
                case 0: // buy $PAC
                    [BREventManager saveEvent:@"tx_history:buy_btc"];
                    [tableView deselectRowAtIndexPath:indexPath animated:YES];
                    //[self showBuy];
                    break;
                    
                case 1: // import private key
                    [BREventManager saveEvent:@"tx_history:import_priv_key"];
                    [self scanQR:nil];
                    break;

                case 2: // settings
                    [BREventManager saveEvent:@"tx_history:settings"];
                    destinationController = [self.storyboard instantiateViewControllerWithIdentifier:@"SettingsViewController"];
                    [self.navigationController pushViewController:destinationController animated:YES];
                    break;
            }

            break;
        }
    }
}

// MARK: - UIViewControllerAnimatedTransitioning

// This is used for percent driven interactive transitions, as well as for container controllers that have companion
// animations that might need to synchronize with the main animation.
- (NSTimeInterval)transitionDuration:(id<UIViewControllerContextTransitioning>)transitionContext
{
    return 0.35;
}

// This method can only be a nop if the transition is interactive and not a percentDriven interactive transition.
- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext
{
    UIView *containerView = transitionContext.containerView;
    UIViewController *to = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey],
                     *from = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    BOOL pop = (to == self || (from != self && [to isKindOfClass:[BRSettingsViewController class]])) ? YES : NO;

    to.view.center = CGPointMake(containerView.frame.size.width*(pop ? -1 : 3)/2, to.view.center.y);
    [containerView addSubview:to.view];

    [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0.0 usingSpringWithDamping:0.8
    initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        to.view.center = from.view.center;
        from.view.center = CGPointMake(containerView.frame.size.width*(pop ? 3 : -1)/2, from.view.center.y);
    } completion:^(BOOL finished) {
        if (pop) [from.view removeFromSuperview];
        [transitionContext completeTransition:YES];
    }];
}

// MARK: - UINavigationControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC
toViewController:(UIViewController *)toVC
{
    return self;
}

// MARK: - UIViewControllerTransitioningDelegate

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    return self;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    return self;
}

@end
