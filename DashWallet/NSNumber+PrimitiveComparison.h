//
//  NSNumber+PrimitiveComparison.h
//  pacwallet
//
//  Created by Alan Valencia on 2/18/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSNumber (PrimitiveComparison)

- (NSComparisonResult) compareWithInt:(int)i;

- (BOOL) isEqualToInt:(int)i;

- (BOOL) isGreaterThanInt:(int)i;

- (BOOL) isGreaterThanOrEqualToInt:(int)i;

- (BOOL) isLessThanInt:(int)i;

- (BOOL) isLessThanOrEqualToInt:(int)i;

@end
