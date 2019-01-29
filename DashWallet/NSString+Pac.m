//
//  NSString+Pac.m
//  PacWallet
//
//  Created by Chase Gray on 2/28/2018.
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

#import "NSString+Pac.h"
#import "NSData+Pac.h"
#import "NSData+Bitcoin.h"
#import "NSString+Bitcoin.h"
#import "NSMutableData+Bitcoin.h"
#import "UIImage+Utils.h"
#import "BRWalletManager.h"
#import "UIColor+Hexadecimal.h"

@implementation NSString (Pac)

// NOTE: It's important here to be permissive with scriptSig (spends) and strict with scriptPubKey (receives). If we
// miss a receive transaction, only that transaction's funds are missed, however if we accept a receive transaction that
// we are unable to correctly sign later, then the entire wallet balance after that point would become stuck with the
// current coin selection code
+ (NSString *)addressWithScriptPubKey:(NSData *)script
{
    if (script == (id)[NSNull null]) return nil;
    
    NSArray *elem = [script scriptElements];
    NSUInteger l = elem.count;
    NSMutableData *d = [NSMutableData data];
    uint8_t v = PAC_PUBKEY_ADDRESS;
    
#if PAC_TESTNET
    v = PAC_PUBKEY_ADDRESS_TEST;
#endif
    
    if (l == 5 && [elem[0] intValue] == OP_DUP && [elem[1] intValue] == OP_HASH160 && [elem[2] intValue] == 20 &&
        [elem[3] intValue] == OP_EQUALVERIFY && [elem[4] intValue] == OP_CHECKSIG) {
        // pay-to-pubkey-hash scriptPubKey
        [d appendBytes:&v length:1];
        [d appendData:elem[2]];
    }
    else if (l == 3 && [elem[0] intValue] == OP_HASH160 && [elem[1] intValue] == 20 && [elem[2] intValue] == OP_EQUAL) {
        // pay-to-script-hash scriptPubKey
        v = PAC_SCRIPT_ADDRESS;
#if PAC_TESTNET
        v = PAC_SCRIPT_ADDRESS_TEST;
#endif
        [d appendBytes:&v length:1];
        [d appendData:elem[1]];
    }
    else if (l == 2 && ([elem[0] intValue] == 65 || [elem[0] intValue] == 33) && [elem[1] intValue] == OP_CHECKSIG) {
        // pay-to-pubkey scriptPubKey
        [d appendBytes:&v length:1];
        [d appendBytes:[elem[0] hash160].u8 length:sizeof(UInt160)];
    }
    else return nil; // unknown script type
    
    return [self base58checkWithData:d];
}


+ (NSString *)addressWithScriptSig:(NSData *)script
{
    if (script == (id)[NSNull null]) return nil;
    
    NSArray *elem = [script scriptElements];
    NSUInteger l = elem.count;
    NSMutableData *d = [NSMutableData data];
    uint8_t v = PAC_PUBKEY_ADDRESS;
    
#if PAC_TESTNET
    v = PAC_PUBKEY_ADDRESS_TEST;
#endif
    
    if (l >= 2 && [elem[l - 2] intValue] <= OP_PUSHDATA4 && [elem[l - 2] intValue] > 0 &&
        ([elem[l - 1] intValue] == 65 || [elem[l - 1] intValue] == 33)) { // pay-to-pubkey-hash scriptSig
        [d appendBytes:&v length:1];
        [d appendBytes:[elem[l - 1] hash160].u8 length:sizeof(UInt160)];
    }
    else if (l >= 2 && [elem[l - 2] intValue] <= OP_PUSHDATA4 && [elem[l - 2] intValue] > 0 &&
             [elem[l - 1] intValue] <= OP_PUSHDATA4 && [elem[l - 1] intValue] > 0) { // pay-to-script-hash scriptSig
        v = PAC_SCRIPT_ADDRESS;
#if PAC_TESTNET
        v = PAC_SCRIPT_ADDRESS_TEST;
#endif
        [d appendBytes:&v length:1];
        [d appendBytes:[elem[l - 1] hash160].u8 length:sizeof(UInt160)];
    }
    else if (l >= 1 && [elem[l - 1] intValue] <= OP_PUSHDATA4 && [elem[l - 1] intValue] > 0) {// pay-to-pubkey scriptSig
        //TODO: implement Peter Wullie's pubKey recovery from signature
        return nil;
    }
    else return nil; // unknown script type
    
    return [self base58checkWithData:d];
}

- (BOOL)isValidPacAddress
{
    if (self.length > 35) return NO;
    
    NSData *d = self.base58checkToData;
    
    if (d.length != 21) return NO;
    
    uint8_t version = *(const uint8_t *)d.bytes;
    
#if PAC_TESTNET
    return (version == PAC_PUBKEY_ADDRESS_TEST || version == PAC_SCRIPT_ADDRESS_TEST) ? YES : NO;
#endif
    
    return (version == PAC_PUBKEY_ADDRESS || version == PAC_SCRIPT_ADDRESS) ? YES : NO;
}

- (BOOL)isValidPacPrivateKey
{
    NSData *d = self.base58checkToData;
    
    if (d.length == 33 || d.length == 34) { // wallet import format: https://en.bitcoin.it/wiki/Wallet_import_format
#if PAC_TESNET
        return (*(const uint8_t *)d.bytes == PAC_PRIVKEY_TEST) ? YES : NO;
#else
        return (*(const uint8_t *)d.bytes == PAC_PRIVKEY) ? YES : NO;
#endif
    }
    else return (self.hexToData.length == 32) ? YES : NO; // hex encoded key
}

// BIP38 encrypted keys: https://github.com/bitcoin/bips/blob/master/bip-0038.mediawiki
- (BOOL)isValidPacBIP38Key
{
    NSData *d = self.base58checkToData;
    
    if (d.length != 39) return NO; // invalid length
    
    uint16_t prefix = CFSwapInt16BigToHost(*(const uint16_t *)d.bytes);
    uint8_t flag = ((const uint8_t *)d.bytes)[2];
    
    if (prefix == BIP38_NOEC_PREFIX) { // non EC multiplied key
        return ((flag & BIP38_NOEC_FLAG) == BIP38_NOEC_FLAG && (flag & BIP38_LOTSEQUENCE_FLAG) == 0 &&
                (flag & BIP38_INVALID_FLAG) == 0) ? YES : NO;
    }
    else if (prefix == BIP38_EC_PREFIX) { // EC multiplied key
        return ((flag & BIP38_NOEC_FLAG) == 0 && (flag & BIP38_INVALID_FLAG) == 0) ? YES : NO;
    }
    else return NO; // invalid prefix
}

- (NSAttributedString*)attributedStringForPacSymbol {
    return [self attributedStringForPacSymbolWithTintColor:[UIColor colorWithHexString:@"#B2B2B2"]];
}

- (NSAttributedString*)attributedStringForPacSymbolWithTintColor:(UIColor*)color {
    return [self attributedStringForPacSymbolWithTintColor:color pacSymbolSize:CGSizeMake(12, 12)];
}

+(NSAttributedString*)pacSymbolAttributedStringWithTintColor:(UIColor*)color forPacSymbolSize:(CGSize)pacSymbolSize {
    NSTextAttachment *pacSymbol = [[NSTextAttachment alloc] init];
    
    pacSymbol.bounds = CGRectMake(0, 0, pacSymbolSize.width, pacSymbolSize.height);
    pacSymbol.image = [[UIImage imageNamed:@"Dash-Light"] imageWithTintColor:color];
    return [NSAttributedString attributedStringWithAttachment:pacSymbol];
}


- (NSAttributedString*)attributedStringForPacSymbolWithTintColor:(UIColor*)color pacSymbolSize:(CGSize)pacSymbolSize {
    
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc]
                                                   initWithString:[self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    
    NSRange range = [attributedString.string rangeOfString:PAC];
    if (range.location == NSNotFound) {
        [attributedString insertAttributedString:[[NSAttributedString alloc] initWithString:@" "] atIndex:0];
        [attributedString insertAttributedString:[NSString pacSymbolAttributedStringWithTintColor:color forPacSymbolSize:pacSymbolSize] atIndex:0];
        
        [attributedString addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, attributedString.length)];
    } else {
        [attributedString replaceCharactersInRange:range
                              withAttributedString:[NSString pacSymbolAttributedStringWithTintColor:color forPacSymbolSize:pacSymbolSize]];
        [attributedString addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, attributedString.length)];
    }
    return attributedString;
}


-(NSInteger)indexOfCharacter:(unichar)character {
    for (int i = 0;i < self.length; i++) {
        if ([self characterAtIndex:i] == character) return i;
    }
    return NSNotFound;
}

// MARK: time

+(NSString*)waitTimeFromNow:(NSTimeInterval)wait {
    NSString * unit = nil;
    NSUInteger seconds = wait;
    NSUInteger hours = seconds / 360;
    seconds %= 360;
    NSUInteger minutes = seconds /60;
    seconds %=60;
    
    NSString * hoursUnit = hours!=1?NSLocalizedString(@"hours",nil):NSLocalizedString(@"hour",nil);
    NSString * minutesUnit = minutes!=1?NSLocalizedString(@"minutes",nil):NSLocalizedString(@"minute",nil);
    NSString * secondsUnit = seconds!=1?NSLocalizedString(@"seconds",nil):NSLocalizedString(@"second",nil);
    NSMutableString * tryAgainTime = [@"" mutableCopy];
    if (hours) {
        [tryAgainTime appendString:[NSString stringWithFormat:@"%ld %@",(unsigned long)hours,hoursUnit]];
        if (minutes && seconds) {
            [tryAgainTime appendString:NSLocalizedString(@", ",nil)];
        } else if (minutes || seconds) {
            [tryAgainTime appendString:NSLocalizedString(@" and ",nil)];
        }
    }
    if (minutes) {
        [tryAgainTime appendString:[NSString stringWithFormat:@"%ld %@",(unsigned long)minutes,minutesUnit]];
        if (seconds) {
            [tryAgainTime appendString:NSLocalizedString(@" and ",nil)];
        }
    }
    if (seconds) {
        [tryAgainTime appendString:[NSString stringWithFormat:@"%ld %@",(unsigned long)seconds,secondsUnit]];
    }
    return [NSString stringWithString:tryAgainTime];
}

@end
