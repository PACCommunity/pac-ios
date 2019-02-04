//
//  UIFont+CustomFont.m
//  pacwallet
//
//  Created by Alan Valencia on 2/3/19.
//  Copyright © 2019 Aaron Voisine. All rights reserved.
//

#import "UIFont+CustomFont.h"
#import <objc/runtime.h>

NSString *const PACRegularFontName = @"Montserrat-Regular";
NSString *const PACMediumFontName = @"Montserrat-Medium";
NSString *const PACBoldFontName = @"Montserrat-Bold";
NSString *const PACBlackFontName = @"Montserrat-Black";
NSString *const PACItalicFontName = @"Montserrat-Italic";
NSString *const PACSemiBoldFontName = @"Montserrat-SemiBold";
NSString *const PACLightFontName = @"ontserrat-Light";

@implementation UIFont (CustomFont)

#pragma clang diagnostic push

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
+ (void)replaceClassSelector:(SEL)originalSelector withSelector:(SEL)modifiedSelector {
    Method originalMethod = class_getClassMethod(self, originalSelector);
    Method modifiedMethod = class_getClassMethod(self, modifiedSelector);
    method_exchangeImplementations(originalMethod, modifiedMethod);
}

+ (void)replaceInstanceSelector:(SEL)originalSelector withSelector:(SEL)modifiedSelector {
    Method originalDecoderMethod = class_getInstanceMethod(self, originalSelector);
    Method modifiedDecoderMethod = class_getInstanceMethod(self, modifiedSelector);
    method_exchangeImplementations(originalDecoderMethod, modifiedDecoderMethod);
}

+ (UIFont *)pacRegularFontWithSize:(CGFloat)size
{
    return [UIFont fontWithName:PACRegularFontName size:size];
}

+ (UIFont *)pacBoldFontWithSize:(CGFloat)size
{
    return [UIFont fontWithName:PACBoldFontName size:size];
}

+ (UIFont *)pacItalicFontOfSize:(CGFloat)fontSize
{
    return [UIFont fontWithName:PACItalicFontName size:fontSize];
}

+ (UIFont *) pacSystemFontOfSize:(CGFloat)fontSize weight:(UIFontWeight)weight {
    
    if (weight == UIFontWeightBold || weight == UIFontWeightHeavy) {
        return [UIFont fontWithName:PACBoldFontName size:fontSize];
    } else if (weight == UIFontWeightMedium) {
        return [UIFont fontWithName:PACMediumFontName size:fontSize];
    } else if (weight == UIFontWeightBlack) {
        return [UIFont fontWithName:PACBlackFontName size:fontSize];
    }  else if (weight == UIFontWeightSemibold) {
        return [UIFont fontWithName:PACSemiBoldFontName size:fontSize];
    }
    
    return [UIFont fontWithName:PACRegularFontName size:fontSize];
}

- (id)initCustomWithCoder:(NSCoder *)aDecoder {
    BOOL result = [aDecoder containsValueForKey:@"UIFontDescriptor"];
    
    if (result) {
        
        UIFontDescriptor *descriptor = [aDecoder decodeObjectForKey:@"UIFontDescriptor"];
        NSString *fontAttribute = descriptor.fontAttributes[@"NSCTFontUIUsageAttribute"];
        
        NSString *fontName;
        if ([fontAttribute isEqualToString:@"CTFontRegularUsage"]) {
            fontName = PACRegularFontName;
        }
        else if ([fontAttribute isEqualToString:@"CTFontEmphasizedUsage"]) {
            fontName = PACBoldFontName;
        }
        else if ([fontAttribute isEqualToString:@"CTFontObliqueUsage"]) {
            fontName = PACItalicFontName;
        } else if ([fontAttribute isEqualToString:@"CTFontMediumUsage"]) {
            fontName = PACMediumFontName;
        } else if ([fontAttribute isEqualToString:@"CTFontBlackUsage"]) {
            fontName = PACBlackFontName;
        } else if ([fontAttribute isEqualToString:@"CTFontLightUsage"]) {
            fontName = PACLightFontName;
        }
        else {
            fontName = descriptor.fontAttributes[@"NSFontNameAttribute"];
        }
        
        return [UIFont fontWithName:fontName size:descriptor.pointSize];
    }
    
    self = [self initCustomWithCoder:aDecoder];
    
    return self;
}

/*+ (void)load
{
    
    [self replaceClassSelector:@selector(systemFontOfSize:weight:)
                  withSelector:@selector(pacSystemFontOfSize:weight:)];
    [self replaceClassSelector:@selector(systemFontOfSize:) withSelector:@selector(pacRegularFontWithSize:)];
    [self replaceClassSelector:@selector(boldSystemFontOfSize:) withSelector:@selector(pacBoldFontWithSize:)];
    [self replaceClassSelector:@selector(italicSystemFontOfSize:) withSelector:@selector(pacItalicFontOfSize:)];
    
    [self replaceInstanceSelector:@selector(initWithCoder:) withSelector:@selector(initCustomWithCoder:)];
}*/
#pragma clang diagnostic pop

@end
