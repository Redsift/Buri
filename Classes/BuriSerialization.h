//
//  BuriSerialization.h
//  Buri
//
//  Created by Gideon de Kok on 10/10/12.
//  Copyright (c) 2012 SpotDog. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol BuriSupport

- (NSDictionary *)buriProperties;

- (id)initWithCoder:(NSCoder *)decoder;
- (void)encodeWithCoder:(NSCoder *)encoder;

@optional
- (id)value:(NSString*)key;

@end

@interface BuriWriteObject : NSObject {
    NSString                *_key;
    NSObject <BuriSupport>  *_value;
    
    NSArray                 *_numericIndexes;
    NSArray                 *_binaryIndexes;
    
    NSDictionary            *_metadata;
}

- (id)initWithBuriObject:(NSObject <BuriSupport> *)buriObject;

- (id)storedObject;
- (NSString *)key;

- (NSArray *)numericIndexes;
- (NSArray *)binaryIndexes;

@end

extern NSString *BURI_KEY;
extern NSString *BURI_VALUE;
extern NSString *BURI_NUMERIC_INDEXES;
extern NSString *BURI_BINARY_INDEXES;
extern NSString *BURI_META_DATA;

