//
//  NSString+Attributed.m
//  pacwallet
//
//  Created by Alan Valencia on 1/22/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "NSString+Attributed.h"

@implementation NSString (Attributed)

- (NSMutableAttributedString *) attributedStringForWord: (NSString *)word attributesFullText: (NSDictionary *) atributesFullText attributtesWord: (NSDictionary *) attributtesWord {
    
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:self attributes: atributesFullText];
    
    NSRange range = [self rangeOfString: word];
    [attrString addAttributes:attributtesWord range:range];
    
    return  attrString;
}

- (NSMutableAttributedString *) attributedStringForWords: (NSArray<NSString *> *)words attributesFullText: (NSDictionary *) atributesFullText attributtesWords: (NSDictionary *) attributtesWords {
    
    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithString:self attributes: atributesFullText];
    
    for (NSString *word in words) {
        NSRange range = [self rangeOfString: word];
        [attrString addAttributes:attributtesWords range:range];
    }
    
    return  attrString;
}

@end
