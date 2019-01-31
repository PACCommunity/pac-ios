//
//  BRTransaction+Date.h
//  pacwallet
//
//  Created by Alan Valencia on 1/28/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "BRTransaction.h"

@interface BRTransaction (Date)

//- (NSString *) dateFormat: (NSString*) template;
- (NSString *) dateForTx: (NSMutableDictionary *) txDates;

@end
