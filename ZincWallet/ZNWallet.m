//
//  ZNWallet.m
//  ZincWallet
//
//  Created by Aaron Voisine on 5/12/13.
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

#import "ZNWallet.h"
#import "ZNTransaction.h"
#import "ZNKey.h"
#import "ZNSocketListener.h"
#import "ZNAddressEntity.h"
#import "ZNTransactionEntity.h"
#import "ZNTxInputEntity.h"
#import "ZNUnspentOutputEntity.h"
#import "NSData+Hash.h"
#import "NSMutableData+Bitcoin.h"
#import "NSString+Base58.h"
#import "NSManagedObject+Utils.h"
#import "AFNetworking.h"

#import "ZNMnemonic.h"
#if WALLET_BIP32
#import "ZNZincMnemonic.h"
#else
#import "ZNElectrumMnemonic.h"
#endif

#import "ZNKeySequence.h"
#if WALLET_BIP32
#import "ZNBIP32Sequence.h"
#else
#import "ZNElectrumSequence.h"
#endif

#define BASE_URL       @"https://blockchain.info"
#define UNSPENT_URL   BASE_URL "/unspent?active="
#define ADDRESS_URL   BASE_URL "/multiaddr?active="
#define PUSHTX_PATH   @"/pushtx"
#define CURRENCY_SIGN @"\xC2\xA4"     // generic currency sign (utf-8)
#define NBSP          @"\xC2\xA0"     // no-break space (utf-8)
#define NARROW_NBSP   @"\xE2\x80\xAF" // narrow no-break space (utf-8)

#define LATEST_BLOCK_HEIGHT_KEY    @"LATEST_BLOCK_HEIGHT"
#define LATEST_BLOCK_TIMESTAMP_KEY @"LATEST_BLOCK_TIMESTAMP"
#define LOCAL_CURRENCY_SYMBOL_KEY  @"LOCAL_CURRENCY_SYMBOL"
#define LOCAL_CURRENCY_CODE_KEY    @"LOCAL_CURRENCY_CODE"
#define LOCAL_CURRENCY_PRICE_KEY   @"LOCAL_CURRENCY_PRICE"
#define LAST_SYNC_TIME_KEY         @"LAST_SYNC_TIME"
#define SEED_KEY                   @"seed"

#define REFERENCE_BLOCK_HEIGHT 250000
#define REFERENCE_BLOCK_TIME   1375533383.0

//( 11111, uint256("0x0000000069e244f73d78e8fd29ba2fd2ed618bd6fa2ee92559f542fdb26e7c1d"))
//( 33333, uint256("0x000000002dd5588a74784eaa7ab0507a18ad16a236e7b1ce69f00d7ddfb5d0a6"))
//( 74000, uint256("0x0000000000573993a3c9e41ce34471c079dcf5f52a0e824a81e7f953b8661a20"))
//(105000, uint256("0x00000000000291ce28027faea320c8d2b054b2e0fe44a773f3eefb151d6bdc97"))
//(134444, uint256("0x00000000000005b12ffd4cd315cd34ffd4a594f430ac814c91184a0d42d2b0fe"))
//(168000, uint256("0x000000000000099e61ea72015e79632f216fe6cb33d7899acb35b75c8303b763"))
//(193000, uint256("0x000000000000059f452a5f7340de6682a977387c17010ff6e6c3bd83ca8b1317"))
//(210000, uint256("0x000000000000048b95347e83192f69cf0366076336c639f9b7228e9ba171342e"))
//(216116, uint256("0x00000000000001b4f4b433e81ee46494af945cf96014816a4e2370f11b23df4e"))
//(225430, uint256("0x00000000000001c108384350f74090433e7fcf79a606b8e797f065b130575932"))
//(250000, uint256("0x000000000000003887df1f29024b06fc2200b55f8af8f35453d7be294df2d214"))
//
//static const CCheckpointData data = {
//    &mapCheckpoints,
//    1375533383, // * UNIX timestamp of last checkpoint block
//    21491097,   // * total number of transactions between genesis and last checkpoint
//                //   (the tx=... number in the SetBestChain debug.log lines)
//    60000.0     // * estimated number of transactions per day after checkpoint
//};

#define SEC_ATTR_SERVICE @"cc.zinc.zincwallet"

static BOOL setKeychainData(NSData *data, NSString *key)
{
    if (! key) return NO;
    
    NSDictionary *query = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService:SEC_ATTR_SERVICE,
                            (__bridge id)kSecAttrAccount:key,
                            (__bridge id)kSecReturnData:(__bridge id)kCFBooleanTrue};
    
    SecItemDelete((__bridge CFDictionaryRef)query);
    
    if (! data) return YES;
    
    NSDictionary *item = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                           (__bridge id)kSecAttrService:SEC_ATTR_SERVICE,
                           (__bridge id)kSecAttrAccount:key,
                           (__bridge id)kSecAttrAccessible:(__bridge id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                           (__bridge id)kSecValueData:data};
    
    return SecItemAdd((__bridge CFDictionaryRef)item, NULL) == noErr ? YES : NO;
}

static NSData *getKeychainData(NSString *key)
{
    NSDictionary *query = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService:SEC_ATTR_SERVICE,
                            (__bridge id)kSecAttrAccount:key,
                            (__bridge id)kSecReturnData:(__bridge id)kCFBooleanTrue};
    CFDataRef result = nil;
    
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result) != noErr) {
        NSLog(@"SecItemCopyMatching error");
        return nil;
    }
    
    return CFBridgingRelease(result);
}

@interface ZNWallet ()

@property (nonatomic, strong) NSMutableSet *updatedTxHashes;
@property (nonatomic, strong) id<ZNKeySequence> sequence;
@property (nonatomic, strong) NSData *mpk;
@property (nonatomic, strong) NSUserDefaults *defs;
@property (nonatomic, strong) NSNumberFormatter *localFormat;

@end

@implementation ZNWallet

+ (instancetype)sharedInstance
{
    static id singleton = nil;
    static dispatch_once_t onceToken = 0;
    
    dispatch_once(&onceToken, ^{
        singleton = [self new];
    });
    
    return singleton;
}

- (instancetype)init
{
    if (! (self = [super init])) return nil;
    
    self.defs = [NSUserDefaults standardUserDefaults];

#if WALLET_BIP32
    self.sequence = [ZNBIP32Sequence new];
#else
     self.sequence = [ZNElectrumSequence new];
#endif
    
    self.format = [NSNumberFormatter new];
    self.format.lenient = YES;
    self.format.numberStyle = NSNumberFormatterCurrencyStyle;
    self.format.minimumFractionDigits = 0;
    self.format.positiveFormat = [self.format.positiveFormat stringByReplacingOccurrencesOfString:CURRENCY_SIGN
                                  withString:CURRENCY_SIGN NARROW_NBSP];
    self.format.negativeFormat = [self.format.positiveFormat stringByReplacingOccurrencesOfString:CURRENCY_SIGN
                                  withString:CURRENCY_SIGN NARROW_NBSP @"-"];
    //self.format.currencySymbol = @"m"BTC@" ";
    //self.format.maximumFractionDigits = 5;
    //self.format.maximum = @21000000000.0;
    self.format.currencySymbol = BTC;
    self.format.maximumFractionDigits = 8;
    self.format.maximum = @21000000.0;
    
    self.localFormat = [NSNumberFormatter new];
    self.localFormat.lenient = YES;
    self.localFormat.numberStyle = NSNumberFormatterCurrencyStyle;
    self.localFormat.negativeFormat =
        [self.localFormat.positiveFormat stringByReplacingOccurrencesOfString:CURRENCY_SIGN
         withString:CURRENCY_SIGN @"-"];
    
    return self;
}

- (NSData *)seed
{
    NSData *seed = getKeychainData(SEED_KEY);
    
    if (seed.length != SEED_LENGTH) {
        self.seed = nil;
        return nil;
    }
    
    return seed;
}

- (void)setSeed:(NSData *)seed
{
    if (seed && [self.seed isEqual:seed]) return;
    
    setKeychainData(seed, SEED_KEY);
    
    _synchronizing = NO;
    self.mpk = nil; // reset master public key

    // remove all core data wallet data
    [[ZNAddressEntity allObjects] makeObjectsPerformSelector:@selector(deleteObject)];
    [[ZNTransactionEntity allObjects] makeObjectsPerformSelector:@selector(deleteObject)];
    [[ZNUnspentOutputEntity allObjects] makeObjectsPerformSelector:@selector(deleteObject)];
    
    // clean out wallet values in user defaults
    [_defs removeObjectForKey:LAST_SYNC_TIME_KEY];

    [NSManagedObject saveContext];
    [_defs synchronize];
}

- (NSString *)seedPhrase
{
#if WALLET_BIP32
    id<ZNMnemonic> mnemonic = [ZNZincMnemonic sharedInstance];
#else
    id<ZNMnemonic> mnemonic = [ZNElectrumMnemonic sharedInstance];
#endif

    return [mnemonic encodePhrase:self.seed];
}

- (void)setSeedPhrase:(NSString *)seedPhrase
{
#if WALLET_BIP32
    id<ZNMnemonic> mnemonic = [ZNZincMnemonic sharedInstance];
#else
    id<ZNMnemonic> mnemonic = [ZNElectrumMnemonic sharedInstance];
#endif

    self.seed = [mnemonic decodePhrase:seedPhrase];
}

- (void)generateRandomSeed
{
    NSMutableData *seed = CFBridgingRelease(CFDataCreateMutable(SecureAllocator(), SEED_LENGTH));
        
    seed.length = SEED_LENGTH;
    SecRandomCopyBytes(kSecRandomDefault, seed.length, seed.mutableBytes);

    self.seed = seed;
}

- (NSData *)masterPublicKey
{
    if (self.mpk) return self.mpk;
    
    self.mpk = [self.sequence masterPublicKeyFromSeed:self.seed];
    return self.mpk;
}

// if any of an unconfimred transaction's inputs show up as unspent, or spent by a confirmed transaction,
// that means the tx failed to confirm and needs to be removed from the tx list
- (void)cleanUnconfirmed
{
    //TODO: remove unconfirmed transactions after 2 days?
    //TODO: keep a seprate list of failed transactions to display along with the successful ones
    [[ZNTransactionEntity objectsMatching:@"blockHeight == 0"]
    enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        ZNTransactionEntity *tx = obj;
        
        // check each tx input
        [tx.inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            ZNTxInputEntity *i = obj;
            
            // if the input is unspent, or spent by a confirmed transaction, delete the unconfirmed tx
            if ([ZNUnspentOutputEntity countObjectsMatching:@"txIndex == %lld && n == %d", i.txIndex, i.n] > 0 ||
                [ZNTxInputEntity countObjectsMatching:@"txIndex == %lld && n == %d && transaction.blockHeight > 0",
                i.txIndex, i.n] > 0) {
                [tx deleteObject];
                *stop = YES;
            }
        }];
    }];
}

#pragma mark - synchronization

- (void)synchronize
{
    if (_synchronizing) return;
    
    _synchronizing = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:walletSyncStartedNotification object:nil];
        
    __block NSMutableArray *gap = [NSMutableArray array];
    
    // a recursive block ARC retain loop is avoided by passing the block as an argument to itself... just shoot me now
    __block void (^completion)(NSError *, id) = ^(NSError *error, void (^completion)(NSError *, id)) {
        if (error) {
            _synchronizing = NO;
            [NSManagedObject saveContext];
            [_defs synchronize];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:walletSyncFailedNotification object:nil
             userInfo:@{@"error":error}];
            return;
        }
        
        // check for previously empty addresses that now have transactions
        [gap filterUsingPredicate:[NSPredicate predicateWithFormat:@"txCount > 0"]];
        
        if (gap.count > 0) { // take the next set of empty addresses and check them for transactions
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [gap setArray:[self addressesWithGapLimit:GAP_LIMIT_EXTERNAL internal:NO]];
                [gap addObjectsFromArray:[self addressesWithGapLimit:GAP_LIMIT_EXTERNAL internal:YES]];
                if (gap.count == 0) return;

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self queryAddresses:gap completion:^(NSError *error) {
                        completion(error, completion);
                    }];
                });
            });
            return;
        }
        
        // remove unconfirmed transactions that no longer appear in query results
        //TODO: keep a seprate list of failed transactions to display along with the successful ones
        [[ZNTransactionEntity objectsMatching:@"blockHeight == 0 && ! (txHash IN %@)", self.updatedTxHashes]
         makeObjectsPerformSelector:@selector(deleteObject)];

        // update the unspent outputs for addresses that have new transactions
        [self queryUnspentOutputs:[ZNAddressEntity objectsMatching:@"newTx == YES"] completion:^(NSError *error) {
            _synchronizing = NO;
            
            if (error) {
                [NSManagedObject saveContext];
                [_defs synchronize];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:walletSyncFailedNotification object:nil
                 userInfo:@{@"error":error}];
                return;
            }
            
            // remove any transactions that failed
            [self cleanUnconfirmed];
            
            [NSManagedObject saveContext];
            [_defs setDouble:[NSDate timeIntervalSinceReferenceDate] forKey:LAST_SYNC_TIME_KEY];
            [_defs synchronize];
            
            [[NSNotificationCenter defaultCenter] postNotificationName:walletSyncFinishedNotification object:nil];
                
            // send balance notification every time since exchange rates might have changed
            [[NSNotificationCenter defaultCenter] postNotificationName:walletBalanceNotification object:nil];
        }];
    };

    // check all the addresses in the wallet for transactions (generating new addresses as needed)
    // generating addresses is slow, but addressesWithGapLimit is thread safe, so we can do that in a separate thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // use external gap limit for the inernal chain to produce fewer network requests
        [gap addObjectsFromArray:[self addressesWithGapLimit:GAP_LIMIT_EXTERNAL internal:NO]];
        [gap addObjectsFromArray:[self addressesWithGapLimit:GAP_LIMIT_EXTERNAL internal:YES]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSArray *used = [ZNAddressEntity objectsMatching:@"! (address IN %@)", [gap valueForKey:@"address"]];
            
            self.updatedTxHashes = [NSMutableSet set]; // reset the updated tx set
            
            // query addresses for transactons, unused addresses first
            [self queryAddresses:[gap arrayByAddingObjectsFromArray:used] completion:^(NSError *error) {
                completion(error, completion);
            }];
        });
    });
}

// Wallets are composed of chains of addresses. Each chain is traversed until a gap of a certain number of addresses is
// found that haven't been used in any transactions. This method returns an array of <gapLimit> unused ZNAddressEntity
// objects following the last used address in the chain. The internal chain is used for change address and the external
// chain for receive addresses.
- (NSArray *)addressesWithGapLimit:(NSUInteger)gapLimit internal:(BOOL)internal
{
    NSMutableArray *newaddresses = [NSMutableArray array];
    NSFetchRequest *req = [ZNAddressEntity fetchRequest];
    
    req.predicate = [NSPredicate predicateWithFormat:@"internal == %@", @(internal)];
    req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES]];
    
    __block NSMutableArray *a = [NSMutableArray arrayWithArray:[ZNAddressEntity fetchObjects:req]];
    __block NSUInteger count = a.count, i = a.count;

    // keep only the trailing contiguous block of addresses with no transactions
    [[NSManagedObject context] performBlockAndWait:^{
        while (i > 0 && [a[i - 1] txCount] == 0) i--;
    }];

    if (i > 0) [a removeObjectsInRange:NSMakeRange(0, i)];
    
    if (a.count >= gapLimit) { // no new addresses need to be generated
        [a removeObjectsInRange:NSMakeRange(gapLimit, a.count - gapLimit)];
        return a;
    }
    
    @synchronized(self) {
        // add any new addresses that were generated while waiting for mutex lock
        req.predicate = [NSPredicate predicateWithFormat:@"internal == %@ && index >= %d", @(internal), count];
        [a addObjectsFromArray:[ZNAddressEntity fetchObjects:req]];
    
        while (a.count < gapLimit) { // generate new addresses up to gapLimit
            unsigned int index = a.count ? [a.lastObject index] + 1 : (unsigned int)count;
            NSData *pubKey = [self.sequence publicKey:index internal:internal masterPublicKey:self.masterPublicKey];
            NSString *addr = [[ZNKey keyWithPublicKey:pubKey] address];

            if (! addr) {
                NSLog(@"error generating keys");
                return nil;
            }

            // store new address in core data
            ZNAddressEntity *address = [ZNAddressEntity entityWithAddress:addr index:index internal:internal];
            
            [a addObject:address];
            [newaddresses addObject:address];
        }
    }
    
    if (newaddresses.count > 0) [[ZNSocketListener sharedInstance] subscribeToAddresses:newaddresses];
    
    return [a subarrayWithRange:NSMakeRange(0, gapLimit)];
}

// query blockchain for transactions involving the given addresses
- (void)queryAddresses:(NSArray *)addresses completion:(void (^)(NSError *error))completion
{
    if (addresses.count == 0) {
        if (completion) completion(nil);
        return;
    }
    
    if (addresses.count > ADDRESSES_PER_QUERY) { // break up into multiple network queries if needed
        [self queryAddresses:[addresses subarrayWithRange:NSMakeRange(0, ADDRESSES_PER_QUERY)]
        completion:^(NSError *error) {
            if (error) {
                if (completion) completion(error);
                return;
            }
            
            [self queryAddresses:[addresses
             subarrayWithRange:NSMakeRange(ADDRESSES_PER_QUERY, addresses.count - ADDRESSES_PER_QUERY)]
             completion:completion];
        }];
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[ADDRESS_URL stringByAppendingString:[[[addresses valueForKey:@"address"]
                  componentsJoinedByString:@"|"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    __block AFJSONRequestOperation *requestOp =
        [AFJSONRequestOperation JSONRequestOperationWithRequest:[NSURLRequest requestWithURL:url]
        success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            if (! _synchronizing) return;
            
            if (! [JSON isKindOfClass:[NSDictionary class]] || ! [JSON[@"addresses"] isKindOfClass:[NSArray class]] ||
                ! [JSON[@"txs"] isKindOfClass:[NSArray class]]) {
                NSError *error = [NSError errorWithDomain:@"ZincWallet" code:500 userInfo:@{
                                  NSLocalizedDescriptionKey:@"Unexpeted server response from blockchain.info"}];

                if (completion) completion(error);
            }
        
            [JSON[@"addresses"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [ZNAddressEntity updateWithJSON:obj]; // update core data address objects
            }];
            
            [JSON[@"txs"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                // updateOrCreateWithJSON will return nil if the tx exists and no updates were made
                ZNTransactionEntity *tx = [ZNTransactionEntity updateOrCreateWithJSON:obj]; // update core data tx objs
                
                if (tx.txHash) [self.updatedTxHashes addObject:tx.txHash];
            }];
        
            // store other useful information from the query result in user defaults
            if ([JSON[@"info"] isKindOfClass:[NSDictionary class]] &&
                [JSON[@"info"][@"latest_block"] isKindOfClass:[NSDictionary class]] &&
                [JSON[@"info"][@"symbol_local"] isKindOfClass:[NSDictionary class]]) {
                
                NSDictionary *b = JSON[@"info"][@"latest_block"];
                NSDictionary *l = JSON[@"info"][@"symbol_local"];
                int height = [b[@"height"] isKindOfClass:[NSNumber class]] ? [b[@"height"] intValue] : 0;
                NSTimeInterval time = [b[@"time"] isKindOfClass:[NSNumber class]] ? [b[@"time"] doubleValue] : 0;
                NSString *symbol = [l[@"symbol"] isKindOfClass:[NSString class]] ? l[@"symbol"] : nil;
                NSString *code = [l[@"code"] isKindOfClass:[NSString class]] ? l[@"code"] : nil;
                double price = [l[@"conversion"] isKindOfClass:[NSNumber class]] ? [l[@"conversion"] doubleValue] : 0;
                    
                if (height > 0) [_defs setInteger:height forKey:LATEST_BLOCK_HEIGHT_KEY];
                if (time > 1.0) [_defs setDouble:time forKey:LATEST_BLOCK_TIMESTAMP_KEY];
                if (symbol.length > 0) [_defs setObject:symbol forKey:LOCAL_CURRENCY_SYMBOL_KEY];
                if (code.length > 0) [_defs setObject:code forKey:LOCAL_CURRENCY_CODE_KEY];
                if (price > DBL_EPSILON) [_defs setDouble:price forKey:LOCAL_CURRENCY_PRICE_KEY];
            }

            if (completion) completion(nil);
        } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
            NSLog(@"%@", error);        
            if (completion) completion(error);
        }];
    
    NSLog(@"%@", url.absoluteString);
    [requestOp start];
}

// query blockchain for unspent outputs for the given addresses
- (void)queryUnspentOutputs:(NSArray *)addresses completion:(void (^)(NSError *error))completion
{
    if (addresses.count == 0) {
        if (completion) completion(nil);
        return;
    }
    
    if (addresses.count > ADDRESSES_PER_QUERY) { // break up into multiple network queries if needed
        [self queryUnspentOutputs:[addresses subarrayWithRange:NSMakeRange(0, ADDRESSES_PER_QUERY)]
        completion:^(NSError *error) {
            if (error) {
                if (completion) completion(error);
                return;
            }
            
            [self queryUnspentOutputs:[addresses
             subarrayWithRange:NSMakeRange(ADDRESSES_PER_QUERY, addresses.count - ADDRESSES_PER_QUERY)]
             completion:completion];
        }];
        return;
    }
    
    NSURL *url = [NSURL URLWithString:[UNSPENT_URL stringByAppendingString:[[[addresses valueForKey:@"address"]
                  componentsJoinedByString:@"|"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    __block AFJSONRequestOperation *requestOp =
        [AFJSONRequestOperation JSONRequestOperationWithRequest:[NSURLRequest requestWithURL:url]
        success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            if (! _synchronizing) return;
            
            // if all outputs have been spent, blockchain.info returns the non-JSON string "no free outputs"
            if (! [requestOp.responseString.lowercaseString hasPrefix:@"no free outputs"] &&
                ! [JSON[@"unspent_outputs"] isKindOfClass:[NSArray class]]) {
                NSError *error = [NSError errorWithDomain:@"ZincWallet" code:500 userInfo:@{
                                  NSLocalizedDescriptionKey:@"Unexpeted server response from blockchain.info"}];

                if (completion) completion(error);
                return;
            }

            NSArray *addrs = [addresses valueForKey:@"address"];
            
            // remove any previously stored unspent outputs for the queried addresses
            [[ZNUnspentOutputEntity objectsMatching:@"address IN %@", addrs]
             makeObjectsPerformSelector:@selector(deleteObject)];
            
            // store any unspent outputs in core data
            [JSON[@"unspent_outputs"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                ZNUnspentOutputEntity *o = [ZNUnspentOutputEntity entityWithJSON:obj];
                    
                if (o.value == 0 || ! [addrs containsObject:o.address]) [o deleteObject];
            }];
            
            [addresses setValue:@(NO) forKey:@"primitiveNewTx"]; // tx successfully synced, reset new tx flag

            if (completion) completion(nil);
        } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
            // if the error is "no free outputs", that's not actually an error
            if (! [requestOp.responseString.lowercaseString hasPrefix:@"no free outputs"]) {
                NSLog(@"%@", error);
                if (completion) completion(error);
                return;
            }
            
            // all outputs have been spent for the requested addresses
            [[ZNUnspentOutputEntity objectsMatching:@"address IN %@", [addresses valueForKey:@"address"]]
             makeObjectsPerformSelector:@selector(deleteObject)];

            [addresses setValue:@(NO) forKey:@"primitiveNewTx"]; // tx successfully synced, reset new tx flag
            
            if (completion) completion(nil);
        }];

    NSLog(@"%@", url.absoluteString);
    [requestOp start];
}

- (NSTimeInterval)timeSinceLastSync
{
    return [NSDate timeIntervalSinceReferenceDate] - [_defs doubleForKey:LAST_SYNC_TIME_KEY];
}

#pragma mark - wallet info

- (uint64_t)balance
{
    // the outputs of unconfirmed transactions will show up in the unspent outputs list even with 0 confirmations
    __block uint64_t balance = 0;
    
    [[ZNUnspentOutputEntity allObjects] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        balance += [(ZNUnspentOutputEntity *)obj value];
    }];
    
    return balance;
}

// returns the next unused address on the requested chain
- (NSString *)addressFromInternal:(BOOL)internal
{
    ZNAddressEntity *addr = [self addressesWithGapLimit:1 internal:internal].lastObject;
    int32_t i = addr.index;
    
    while (i > 0) { // consider an address still unused if none of its transactions have at least 6 confimations
        ZNAddressEntity *a =
            [ZNAddressEntity objectsMatching:@"internal == %@ && index == %d", @(internal), --i].lastObject;
        
        if (a.txCount > 0) {
            NSArray *unspent = [ZNUnspentOutputEntity objectsMatching:@"address == %@ && confirmations < 6", a.address];
    
            // if number of unique txIndexes with < 6 confirms is less than txCount, at least one tx has > 6 confirms
            if ([[NSSet setWithArray:[unspent valueForKey:@"primitiveTxIndex"]] count] < a.txCount) break;
        }

        if (a) addr = a;
    }
    
    return addr.address;
}

- (NSString *)receiveAddress
{
    return [self addressFromInternal:NO];
}

- (NSString *)changeAddress
{
    return [self addressFromInternal:YES];
}

- (NSArray *)recentTransactions
{
    // sort in descending order by timestamp (using block_height doesn't work for unconfirmed, or multiple tx per block)
    return [ZNTransactionEntity objectsSortedBy:@"timeStamp" ascending:NO];
}

- (uint32_t)lastBlockHeight
{
    uint32_t height = (uint32_t)[_defs integerForKey:LATEST_BLOCK_HEIGHT_KEY];
    
    if (! height) height = REFERENCE_BLOCK_HEIGHT;
    
    return height;
}

- (uint32_t)estimatedCurrentBlockHeight
{
    NSTimeInterval time = [_defs doubleForKey:LATEST_BLOCK_TIMESTAMP_KEY];
    
    if (time < 1.0) time = REFERENCE_BLOCK_TIME;
    
    // average one block every 600 seconds
    return self.lastBlockHeight + ([NSDate timeIntervalSinceReferenceDate] + NSTimeIntervalSince1970 - time)/600;
}

- (BOOL)containsAddress:(NSString *)address
{
    return [ZNAddressEntity countObjectsMatching:@"address == %@", address] > 0;
}

#pragma mark - string helpers

- (int64_t)amountForString:(NSString *)string
{
    return ([[self.format numberFromString:string] doubleValue] + DBL_EPSILON)*
           pow(10.0, self.format.maximumFractionDigits);
}

- (NSString *)stringForAmount:(int64_t)amount
{
    NSUInteger min = self.format.minimumFractionDigits;
    
    if (amount == 0) {
        self.format.minimumFractionDigits =
            self.format.maximumFractionDigits > 4 ? 4 : self.format.maximumFractionDigits;
    }
    
    NSString *r = [self.format stringFromNumber:@(amount/pow(10.0, self.format.maximumFractionDigits))];
    
    self.format.minimumFractionDigits = min;
    
    return r;
}

- (NSString *)localCurrencyStringForAmount:(int64_t)amount
{
    if (! amount) return [self.localFormat stringFromNumber:@(0)];

    NSString *symbol = [_defs stringForKey:LOCAL_CURRENCY_SYMBOL_KEY];
    NSString *code = [_defs stringForKey:LOCAL_CURRENCY_CODE_KEY];
    double price = [_defs doubleForKey:LOCAL_CURRENCY_PRICE_KEY];
    
    if (! symbol.length || price <= DBL_EPSILON) return nil;
    
    self.localFormat.currencySymbol = symbol;
    self.localFormat.currencyCode = code;
    
    NSString *ret = [self.localFormat stringFromNumber:@(amount/price)];
    
    // if the amount is too small to be represented in local currency (but is != 0) then return a string like "<$0.01"
    if (amount != 0 && [[self.localFormat numberFromString:ret] isEqual:@(0.0)]) {
        ret = [@"<" stringByAppendingString:[self.localFormat
               stringFromNumber:@(1.0/pow(10.0, self.localFormat.maximumFractionDigits))]];
    }
    
    return ret;
}

#pragma mark - ZNTransaction helpers

- (ZNTransaction *)transactionFor:(uint64_t)amount to:(NSString *)address withFee:(BOOL)fee
{
    __block uint64_t balance = 0, standardFee = 0;
    uint64_t minChange = fee ? TX_MIN_OUTPUT_AMOUNT : TX_FREE_MIN_OUTPUT;
    ZNTransaction *tx = [ZNTransaction new];

    [tx addOutputAddress:address amount:amount];

    //TODO: optimize for free transactions (watch out for performance issues, nothing O(n^2) please)
    // this is a nieve implementation to just get it functional, sorts unspent outputs by oldest first
    [[ZNUnspentOutputEntity objectsSortedBy:@"txIndex" ascending:YES]
    enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [tx addInputHash:[obj txHash] index:[obj n] script:[obj script]]; // txHash is already in little endian
            
        balance += [(ZNUnspentOutputEntity *)obj value];

        // assume we will be adding a change output (additional 34 bytes)
        //TODO: calculate the median of the lowest fee-per-kb that made it into the previous 144 blocks (24hrs)
        if (fee) standardFee = ((tx.size + 34 + 999)/1000)*TX_FEE_PER_KB;
            
        if (balance == amount + standardFee || balance >= amount + standardFee + minChange) *stop = YES;
    }];
    
    if (balance < amount + standardFee) { // insufficent funds
        NSLog(@"Insufficient funds. %llu is less than transaction amount:%llu", balance, amount + standardFee);
        return nil;
    }
    
    //TODO: randomly swap order of outputs so the change address isn't publicy known
    if (balance - (amount + standardFee) >= TX_MIN_OUTPUT_AMOUNT) {
        [tx addOutputAddress:self.changeAddress amount:balance - (amount + standardFee)];
    }
    
    return tx;
}

// returns the estimated time in seconds until the transaction will be processed without a fee.
// this is based on the default satoshi client settings, but on the real network it's way off. in testing, a 0.01btc
// transaction with a 90 day time until free was confirmed in under an hour by Eligius pool.
- (NSTimeInterval)timeUntilFree:(ZNTransaction *)transaction
{
    // TODO: calculate estimated time based on the median priority of free transactions in last 144 blocks (24hrs)
    NSMutableArray *amounts = [NSMutableArray array], *heights = [NSMutableArray array];
    NSUInteger currentHeight = [_defs integerForKey:LATEST_BLOCK_HEIGHT_KEY];
    
    if (! currentHeight) return DBL_MAX;
    
    // get the heights (which block in the blockchain it's in) of all the transaction inputs
    [transaction.inputAddresses enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        ZNUnspentOutputEntity *o = [ZNUnspentOutputEntity objectsMatching:@"txHash == %@ && n == %d",
                                    transaction.inputHashes[idx], [transaction.inputIndexes[idx] intValue]].lastObject;

        if (o) {
            [amounts addObject:@(o.value)];
            [heights addObject:@(currentHeight - o.confirmations)];
        }
        else *stop = YES;
    }];

    NSUInteger height = [transaction blockHeightUntilFreeForAmounts:amounts withBlockHeights:heights];
    
    if (height == NSNotFound) return DBL_MAX;
    
    currentHeight = [self estimatedCurrentBlockHeight];
    
    return height > currentHeight + 1 ? (height - currentHeight)*600 : 0;
}

// retuns the total amount of the trasaction including any fees
- (uint64_t)transactionAmount:(ZNTransaction *)transaction
{
    __block uint64_t amount = 0;
    
    [transaction.inputAddresses enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        ZNUnspentOutputEntity *o = [ZNUnspentOutputEntity objectsMatching:@"txHash == %@ && n == %d",
                                    transaction.inputHashes[idx], [transaction.inputIndexes[idx] intValue]].lastObject;
        
        if (! o) {
            amount = 0;
            *stop = YES;
        }
        else amount += o.value;
    }];

    return amount;
}

// returns the transaction fee for the given transaction
- (uint64_t)transactionFee:(ZNTransaction *)transaction
{
    __block uint64_t amount = [self transactionAmount:transaction];

    if (amount == 0) return UINT64_MAX;
    
    [transaction.outputAmounts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        amount -= [obj unsignedLongLongValue];
    }];
    
    return amount;
}

- (BOOL)signTransaction:(ZNTransaction *)transaction
{
    NSArray *externalIndexes = [[ZNAddressEntity objectsMatching:@"internal == NO && address IN %@",
                                 transaction.inputAddresses] valueForKey:@"primitiveIndex"];
    NSArray *internalIndexes = [[ZNAddressEntity objectsMatching:@"internal == YES && address IN %@",
                                 transaction.inputAddresses] valueForKey:@"primitiveIndex"];
    NSMutableArray *pkeys = [NSMutableArray arrayWithCapacity:externalIndexes.count + internalIndexes.count];
    NSData *seed = self.seed;
    
    [pkeys addObjectsFromArray:[self.sequence privateKeys:externalIndexes internal:NO fromSeed:seed]];
    [pkeys addObjectsFromArray:[self.sequence privateKeys:internalIndexes internal:YES fromSeed:seed]];
    
    [transaction signWithPrivateKeys:pkeys];
    
    seed = nil;
    pkeys = nil;
    
    return [transaction isSigned];
}

// given a private key, queries blockchain for unspent outputs and calls the completion block with a signed transaction
// that will sweep the balance into wallet (doesn't publish the tx)
- (void)sweepPrivateKey:(NSString *)privKey withFee:(BOOL)fee
completion:(void (^)(ZNTransaction *tx, NSError *error))completion
{
    NSString *address = [[ZNKey keyWithPrivateKey:privKey] address];

    if (! address || ! completion) return;
    
    if ([self containsAddress:address]) {
        completion(nil, [NSError errorWithDomain:@"ZincWallet" code:187
                         userInfo:@{NSLocalizedDescriptionKey:@"This private key is already in your wallet."}]);
        return;
    }
    
    if (_synchronizing) {
        completion(nil, [NSError errorWithDomain:@"ZincWallet" code:1
                         userInfo:@{NSLocalizedDescriptionKey:@"Wait for wallet sync to finish."}]);
        return;
    }
    
    _synchronizing = YES;
    // pass in a mutable dictionary in place of a ZNAddressEntity to avoid storing the address in core data
    [self queryUnspentOutputs:@[[@{@"address":address} mutableCopy]] completion:^(NSError *error) {
        _synchronizing = NO;
        
        if (error) {
            completion(nil, error);
            return;
        }
        
        __block uint64_t balance = 0, standardFee = 0;
        ZNTransaction *tx = [ZNTransaction new];
        
        [[ZNUnspentOutputEntity objectsMatching:@"address == %@", address]
        enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [tx addInputHash:[obj txHash] index:[obj n] script:[obj script]]; // txHash is already in little endian
            
            balance += [(ZNUnspentOutputEntity *)obj value];

            [obj deleteObject]; // immediately remove unspent output from core data
        }];
        
        if (balance == 0) {
            completion(nil, [NSError errorWithDomain:@"ZincWallet" code:417
                             userInfo:@{NSLocalizedDescriptionKey:@"This private key is empty."}]);
            return;
        }

        // we will be adding a wallet output (additional 34 bytes)
        //TODO: calculate the median of the lowest fee-per-kb that made it into the previous 144 blocks (24hrs)
        if (fee) standardFee = ((tx.size + 34 + 999)/1000)*TX_FEE_PER_KB;

        if (standardFee + TX_MIN_OUTPUT_AMOUNT > balance) {
            completion(nil, [NSError errorWithDomain:@"ZincWallet" code:417
                             userInfo:@{NSLocalizedDescriptionKey:@"Transaction fees would cost more than the funds "
                             "available on this private key to transfer. (due to tiny \"dust\" deposits)"}]);
            return;
        }
        
        [tx addOutputAddress:[self changeAddress] amount:balance - standardFee];

        if (! [tx signWithPrivateKeys:@[privKey]]) {
            completion(nil, [NSError errorWithDomain:@"ZincWallet" code:401
                       userInfo:@{NSLocalizedDescriptionKey:@"Error signing transaction."}]);
            return;
        }
        
        completion(tx, nil);
    }];
}

- (void)publishTransaction:(ZNTransaction *)transaction completion:(void (^)(NSError *error))completion
{
    if (! [transaction isSigned]) {
        if (completion) {
            completion([NSError errorWithDomain:@"ZincWallet" code:401
                        userInfo:@{NSLocalizedDescriptionKey:@"bitcoin transaction not signed"}]);
        }
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:walletSyncStartedNotification object:nil];
    
    AFHTTPClient *client = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:BASE_URL]];

    [client postPath:PUSHTX_PATH parameters:@{@"tx":[transaction toHex]}
    success:^(AFHTTPRequestOperation *operation, id responseObject) {        
        //NOTE: successful response is "Transaction submitted", maybe we should check for that
        NSLog(@"responseObject: %@", responseObject);
        NSLog(@"response:\n%@", operation.responseString);
        
        // delete any unspent outputs that are now spent
        [transaction.inputHashes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [[ZNUnspentOutputEntity objectsMatching:@"txHash == %@ && n == %d", obj,
              [transaction.inputIndexes[idx] intValue]].lastObject deleteObject];
        }];
        
        // add change to unspent outputs
        [transaction.outputAddresses enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([self containsAddress:obj] &&
                [ZNUnspentOutputEntity countObjectsMatching:@"txHash == %@ && n == %d", transaction.txHash, idx] == 0) {
                [ZNUnspentOutputEntity entityWithAddress:obj txHash:transaction.txHash n:(unsigned int)idx
                 value:[transaction.outputAmounts[idx] longLongValue]];
            }
        }];
        
        // add the transaction to the tx list
        if ([ZNTransactionEntity countObjectsMatching:@"txHash == %@", transaction.txHash] == 0) {
            [[ZNTransactionEntity managedObject] setAttributesFromTx:transaction];
        }
        
        [NSManagedObject saveContext];
        [_defs synchronize];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:walletSyncFinishedNotification object:nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:walletBalanceNotification object:nil];
        if (completion) completion(nil);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [[NSNotificationCenter defaultCenter] postNotificationName:walletSyncFailedNotification object:nil
         userInfo:@{@"error":error}];

        NSLog(@"%@", operation.responseString);
        if (completion) completion(error);
    }];

    //TODO: also publish transactions directly to coinbase and bitpay servers for faster POS experience
}

@end
