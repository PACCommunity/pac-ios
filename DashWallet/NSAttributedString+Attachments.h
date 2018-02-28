//
//  NSAttributedString+Attachments.h
//  PacWallet
//
//  Created by Chase Gray on 2/28/2018
//

#import <Foundation/Foundation.h>

@interface NSAttributedString (Attachments)

- (NSArray *)allAttachments;
- (NSTextAttachment *)firstAttachment;

@end
