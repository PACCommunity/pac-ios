//
//  NSString+Attributed.h
//  pacwallet
//
//  Created by Alan Valencia on 1/22/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Attributed)

- (NSMutableAttributedString *) attributedStringForWord: (NSString *)word attributesFullText: (NSDictionary *) atributesFullText attributtesWord: (NSDictionary *) attributtesWord;

- (NSMutableAttributedString *) attributedStringForWords: (NSArray<NSString *> *)words attributesFullText: (NSDictionary *) atributesFullText attributtesWords: (NSDictionary *) attributtesWords;

@end
