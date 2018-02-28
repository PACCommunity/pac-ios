//
//  NSString+Pac.h
//  PacWallet
//
//  Created by Chase Gray on 2/28/2018
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define PAC_PUBKEY_ADDRESS      76
#define PAC_SCRIPT_ADDRESS      16
#define PAC_PUBKEY_ADDRESS_TEST 140
#define PAC_SCRIPT_ADDRESS_TEST 19
#define PAC_PRIVKEY             204
#define PAC_PRIVKEY_TEST        239

#define BIP38_NOEC_PREFIX      0x0142
#define BIP38_EC_PREFIX        0x0143
#define BIP38_NOEC_FLAG        (0x80 | 0x40)
#define BIP38_COMPRESSED_FLAG  0x20
#define BIP38_LOTSEQUENCE_FLAG 0x04
#define BIP38_INVALID_FLAG     (0x10 | 0x08 | 0x02 | 0x01)

@interface NSString (Pac)


+ (NSString *)addressWithScriptPubKey:(NSData *)script;
+ (NSString *)addressWithScriptSig:(NSData *)script;

- (NSAttributedString*)attributedStringForPacSymbol;
- (NSAttributedString*)attributedStringForPacSymbolWithTintColor:(UIColor*)color;
- (NSAttributedString*)attributedStringForPacSymbolWithTintColor:(UIColor*)color pacSymbolSize:(CGSize)pacSymbolSize;
+ (NSAttributedString*)pacSymbolAttributedStringWithTintColor:(UIColor*)color forPacSymbolSize:(CGSize)pacSymbolSize;

- (BOOL)isValidPacAddress;
- (BOOL)isValidPacPrivateKey;
- (BOOL)isValidPacBIP38Key; // BIP38 encrypted keys: https://github.com/bitcoin/bips/blob/master/bip-0038.mediawiki

-(NSInteger)indexOfCharacter:(unichar)character;

+(NSString*)waitTimeFromNow:(NSTimeInterval)wait;

@end
