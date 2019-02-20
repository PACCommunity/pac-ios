//
//  NSNumber+PrimitiveComparison.m
//  pacwallet
//
//  Created by Alan Valencia on 2/18/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "NSNumber+PrimitiveComparison.h"

@implementation NSNumber (PrimitiveComparison)

- (NSComparisonResult) compareWithInt:(int)i{
    return [self compare:[NSNumber numberWithInt:i]];
}

- (BOOL) isEqualToInt:(int)i{
    return [self compareWithInt:i] == NSOrderedSame;
}

- (BOOL) isGreaterThanInt:(int)i{
    return [self compareWithInt:i] == NSOrderedDescending;
}

- (BOOL) isGreaterThanOrEqualToInt:(int)i{
    return [self isGreaterThanInt:i] || [self isEqualToInt:i];
}

- (BOOL) isLessThanInt:(int)i{
    return [self compareWithInt:i] == NSOrderedAscending;
}

- (BOOL) isLessThanOrEqualToInt:(int)i{
    return [self isLessThanInt:i] || [self isEqualToInt:i];
}

@end
