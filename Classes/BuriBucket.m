//
//  BuriBucket.cpp
//  Buri
//
//  Created by Gideon de Kok on 10/10/12.
//  Copyright (c) 2012 SpotDog. All rights reserved.
//

#import "BuriBucket.h"
#import "BuriSerialization.h"
#import "BuriIndex.h"

@implementation BuriBucket

@synthesize buri		= _buri;
@synthesize usedClass	= _usedClass;

- (id)initWithDB:(Buri *)aDb andName:(NSString*)aName andObjectClass:(Class <BuriSupport>)aClass
{
	self = [super init];

	if (self) {
		_buri		= aDb;
        _name		= aName; // NSStringFromClass(aClass);
		_usedClass	= aClass;
		[self initBucketPointer];
	}

	return self;
}

#pragma mark -
#pragma mark Prefix generators

- (NSString *)prefixKey:(NSString *)origKey
{
	return [NSString stringWithFormat:@"2i_%@::%@", _name, origKey];
}

- (NSString *)prefixBinaryIndexKey:(NSString *)origKey
{
	return [NSString stringWithFormat:@"2i_%@_bin::%@", _name, origKey];
}

- (NSString *)prefixNumericIndexKey:(NSString *)origKey
{
	return [NSString stringWithFormat:@"2i_%@_int::%@", _name, origKey];
}

- (NSString *)removePrefixFromKey:(NSString *)prefixedKey
{
	NSUInteger slicePosition = [prefixedKey rangeOfString:[self bucketPointerKey]].length;

	return [prefixedKey substringFromIndex:slicePosition];
}

#pragma mark -
#pragma mark Index key generators

- (NSString *)indexKeyForBinaryIndex:(BuriBinaryIndex *)index writeObject:(BuriWriteObject *)wo
{
	return [self prefixBinaryIndexKey:[NSString stringWithFormat:@"%@->%@->%@", [index key], [index value], [wo key]]];
}

- (NSString *)indexKeyForNumericIndex:(BuriNumericIndex *)index writeObject:(BuriWriteObject *)wo
{
	return [self prefixNumericIndexKey:[NSString stringWithFormat:@"%@->%@->%@", [index key], [index value], [wo key]]];
}

- (NSString *)indexValueForBinaryIndexKey:(NSString *)indexKey
{
    @try {
        NSRange firstSliceRange = [indexKey rangeOfString:@"->"];
        NSString *firstSlice = [indexKey substringFromIndex:firstSliceRange.location + firstSliceRange.length];
        NSRange secondSliceRange = [firstSlice rangeOfString:@"->"];
        NSString *indexValue = [firstSlice substringToIndex:secondSliceRange.location];
        
        return indexValue;
    }
    @catch (NSException *exception) {
        return nil;
    }
    
}

- (NSNumber *)indexValueForNumericIndexKey:(NSString *)indexKey
{
    @try {
        NSRange firstSliceRange = [indexKey rangeOfString:@"->"];
        NSString *firstSlice = [indexKey substringFromIndex:firstSliceRange.location + firstSliceRange.length];
        NSRange secondSliceRange = [firstSlice rangeOfString:@"->"];
        if(secondSliceRange.location == NSNotFound) {
            return nil;
        }
        NSString *numberAsString = [firstSlice substringToIndex:secondSliceRange.location];
        
        NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
        return [f numberFromString:numberAsString];
    }
    @catch (NSException *exception) {
        return nil;
    }
    
}

#pragma mark -
#pragma mark Bucket pointers

- (NSString *)bucketPointerKey
{
	return [self prefixKey:@""];
}

- (NSString *)exactBinaryIndexPointerForIndexKey:(NSString *)key value:(NSString *)value
{
    return [self prefixBinaryIndexKey:[NSString stringWithFormat:@"%@->%@", key, value]];
}

- (NSString *)exactNumericIndexPointerForIndexKey:(NSString *)key value:(NSNumber *)value
{
    return [self prefixNumericIndexKey:[NSString stringWithFormat:@"%@->%@", key, value]];
}

- (NSString *)rangeNumericIndexPointerForIndexKey:(NSString *)key
{
    return [self prefixNumericIndexKey:[NSString stringWithFormat:@"%@->", key]];
}

- (void)initBucketPointer
{
	NSString *value = [_buri getObject:[self bucketPointerKey]];

	if (!value) {
		[_buri putObject:@"*" forKey:[self bucketPointerKey]];
	}
}

- (void)initExactBinaryIndexPointerForIndexKey:(NSString *)key value:(NSString *)value
{                  
    NSString *idxValue = [_buri getObject:[self exactBinaryIndexPointerForIndexKey:key value:value]];
    
	if (!idxValue) {
		[_buri putObject:@"*" forKey:[self exactBinaryIndexPointerForIndexKey:key value:value]];
	}
}

- (void)initExactNumericIndexPointerForIndexKey:(NSString *)key value:(NSNumber *)value
{
    NSString *idxValue = [_buri getObject:[self exactNumericIndexPointerForIndexKey:key value:value]];
    
	if (!idxValue) {
		[_buri putObject:@"*" forKey:[self exactNumericIndexPointerForIndexKey:key value:value]];
	}
}

- (void)initRangeNumericIndexPointerForIndexKey:(NSString *)key
{
    NSString *idxValue = [_buri getObject:[self rangeNumericIndexPointerForIndexKey:key]];
    
	if (!idxValue) {
		[_buri putObject:@"*" forKey:[self rangeNumericIndexPointerForIndexKey:key]];
	}
}


#pragma mark -
#pragma mark Fetch methods

- (id)fetchObjectForKey:(NSString *)key
{
    if (key.length == 0) {
        return nil;
    }

	BuriWriteObject *wo = [_buri getObject:[self prefixKey:key]];

	return [wo storedObject];
}

- (NSArray *)fetchKeysForBinaryIndex:(NSString *)indexField value:(NSString *)indexValue
{
    return [self _fetchKeyValuesForBinaryIndex:indexField value:indexValue loadValue:false];
}

- (NSArray *)fetchObjectsForBinaryIndex:(NSString *)indexField value:(NSString *)indexValue
{
    NSArray *keys = [self fetchKeysForBinaryIndex:indexField value:indexValue];
    NSMutableArray *objects = [NSMutableArray array];
    for (NSDictionary *keyValue in keys) {
        NSString *key = keyValue[@"key"];
        id value = [_buri getObject:[self prefixKey:key]];
        if ([value isMemberOfClass:[BuriWriteObject class]]) {
            [objects addObject:[(BuriWriteObject *) value storedObject]];
        }
    }
    
    return objects;
}

- (NSArray *)fetchKeysForNumericIndex:(NSString *)indexField value:(NSNumber *)indexValue
{
    return [self _fetchKeyValuesForNumericIndex:indexField value:indexValue loadValue:false];
}

- (NSArray *)fetchKeysForNumericIndex:(NSString *)indexField from:(NSNumber *)fromValue to:(NSNumber *)toValue
{
    return [self _fetchKeyValuesForNumericIndex:indexField from:fromValue to:toValue loadValue:false];
}

- (NSArray *)fetchObjectsForNumericIndex:(NSString *)indexField value:(NSNumber *)indexValue
{
    NSArray *keys = [self fetchKeysForNumericIndex:indexField value:indexValue];
    NSMutableArray *objects = [NSMutableArray array];
    for (NSDictionary *keyValue in keys) {
        NSString *key = keyValue[@"key"];
        id value = [_buri getObject:[self prefixKey:key]];
        if ([value isMemberOfClass:[BuriWriteObject class]]) {
            [objects addObject:[(BuriWriteObject *) value storedObject]];
        }
    }
    
    return objects;
}

- (NSArray *)fetchObjectsForNumericIndex:(NSString *)indexField from:(NSNumber *)fromValue to:(NSNumber *)toValue
{
    NSArray *keys = [self fetchKeysForNumericIndex:indexField from:fromValue to:toValue];
    NSMutableArray *objects = [NSMutableArray array];
    for (NSDictionary *keyValue in keys) {
        NSString *key = keyValue[@"key"];
        id value = [_buri getObject:[self prefixKey:key]];
        if ([value isMemberOfClass:[BuriWriteObject class]]) {
            [objects addObject:[(BuriWriteObject *) value storedObject]];
        }
    }
    
    return objects;
}

- (NSArray *)_fetchKeyValuesForBinaryIndex:(NSString *)indexField value:(NSString *)indexValue loadValue:(BOOL)loadValue {
    NSMutableArray *keyValues = [[NSMutableArray alloc] init];
    NSString *indexPointer = [self exactBinaryIndexPointerForIndexKey:indexField value:indexValue];
    
    [_buri seekToKey:indexPointer andIterate:^BOOL (NSString * key, id keyValue) {
        if ([key rangeOfString:indexPointer].location != 0)
            return NO;
        
        if (keyValue) {
            NSString *stringVal = [self indexValueForBinaryIndexKey:key];
            
            if (stringVal)
            {
                id object = [_buri getObject:[self prefixKey:keyValue]];
                if ([object isMemberOfClass:[BuriWriteObject class]]) {
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:3];
                    dict[@"key"] = keyValue;
                    dict[@"index"] = stringVal;
                    if(loadValue) {
                        dict[@"value"] = [[(BuriWriteObject *) object storedObject] internalObject];
                    }
                    [keyValues addObject:dict];
                }
            }
        }
        return YES;
    }];
    
    // Remove pointer
    //if ([keys count] > 0) {
    //    [keys removeObjectAtIndex:0];
    //}
    
    return keyValues;
}

- (NSArray *)fetchKeyValuesForBinaryIndex:(NSString *)indexField value:(NSString *)indexValue {
    return [self _fetchKeyValuesForBinaryIndex:indexField value:indexValue loadValue:true];
}

- (NSArray *)_fetchKeyValuesForNumericIndex:(NSString *)indexField value:(NSNumber *)indexValue loadValue:(BOOL)loadValue
{
    NSMutableArray *keyValues = [[NSMutableArray alloc] init];
    NSString *indexPointer = [self exactNumericIndexPointerForIndexKey:indexField value:indexValue];
    
    [_buri seekToKey:indexPointer andIterate:^BOOL (NSString * key, id keyValue) {
        if ([key rangeOfString:indexPointer].location != 0)
            return NO;
        
        if (keyValue) {
            NSNumber *numVal = [self indexValueForNumericIndexKey:key];
            
            if (numVal)
            {
                id object = [_buri getObject:[self prefixKey:keyValue]];
                if ([object isMemberOfClass:[BuriWriteObject class]]) {
                    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:3];
                    dict[@"key"] = keyValue;
                    dict[@"index"] = numVal;
                    if(loadValue) {
                        dict[@"value"] = [[(BuriWriteObject *) object storedObject] internalObject];
                    }
                    [keyValues addObject:dict];
                }
            }
        }
        return YES;
    }];
    
    // Remove pointer
    //if ([keys count] > 0) {
    //    [keys removeObjectAtIndex:0];
    //}
    
    return keyValues;
}

- (NSArray *)fetchKeyValuesForNumericIndex:(NSString *)indexField value:(NSNumber *)indexValue
{
    return [self _fetchKeyValuesForNumericIndex:indexField value:indexValue loadValue:true];
}

- (NSArray *)_fetchKeyValuesForNumericIndex:(NSString *)indexField from:(NSNumber *)fromValue to:(NSNumber *)toValue loadValue:(BOOL)loadValue
{
    NSMutableArray *keyValues = [[NSMutableArray alloc] init];
    NSString *indexPointer = [self rangeNumericIndexPointerForIndexKey:indexField];
    
    [_buri seekToKey:indexPointer andIterate:^BOOL (NSString * key, id keyValue) {
        if ([key rangeOfString:indexPointer].location != 0)
            return NO;
        
        if (keyValue)
        {
            NSNumber *numVal = [self indexValueForNumericIndexKey:key];
            
            if (numVal)
            {
                if ([numVal doubleValue] > [toValue doubleValue])
                    return NO;
                
                if ([numVal doubleValue] > [fromValue doubleValue])
                {
                    id object = [_buri getObject:[self prefixKey:keyValue]];
                    if ([object isMemberOfClass:[BuriWriteObject class]]) {
                        NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithCapacity:3];
                        dict[@"key"] = keyValue;
                        dict[@"index"] = numVal;
                        if(loadValue) {
                            dict[@"value"] = [[(BuriWriteObject *) object storedObject] internalObject];
                        }
                        [keyValues addObject:dict];
                    }
                }
            }
        }
        return YES;
    }];
    
    return keyValues;
}

- (NSArray *)fetchKeyValuesForNumericIndex:(NSString *)indexField from:(NSNumber *)fromValue to:(NSNumber *)toValue {
    return [self _fetchKeyValuesForNumericIndex:indexField from:fromValue to:toValue loadValue:true];
}

- (NSArray *)allKeys
{
	NSMutableArray *keys = [[NSMutableArray alloc] init];

	[_buri seekToKey:[self bucketPointerKey] andIterateKeys:^BOOL (NSString * key) {
			if ([key rangeOfString:[self bucketPointerKey]].location != 0)
				return NO;

            NSString *strippedKey = [self removePrefixFromKey:key];
            if(strippedKey != nil && ![strippedKey isEqual: @""]) {
                [keys addObject: strippedKey];
                return YES;
            }
            return YES;
		}];

	// Remove pointer
    //if ([keys count] > 0) {
    //    [keys removeObjectAtIndex:0];
    //}
    
	return keys;
}

- (NSArray *)allObjects
{
	NSMutableArray *objects = [[NSMutableArray alloc] init];

	[_buri seekToKey:[self bucketPointerKey] andIterate:^BOOL (NSString * key, id value) {
			if ([key rangeOfString:[self bucketPointerKey]].location != 0)
				return NO;

			if ([value isMemberOfClass:[BuriWriteObject class]]) {
				[objects addObject:[(BuriWriteObject *) value storedObject]];
			}

			return YES;
		}];

	return objects;
}

- (NSArray *)allKeyValues
{
    NSMutableArray *keyValues = [[NSMutableArray alloc] init];
    
    [_buri seekToKey:[self bucketPointerKey] andIterate:^BOOL (NSString * key, id value) {
        if ([key rangeOfString:[self bucketPointerKey]].location != 0)
            return NO;
        
        if ([value isMemberOfClass:[BuriWriteObject class]]) {
            id storedObject = [(BuriWriteObject *) value storedObject];

            [keyValues addObject:@{@"key": [self removePrefixFromKey:key], @"value": [storedObject internalObject]}];
        }
        
        return YES;
    }];
    
    return keyValues;
}

#pragma mark -
#pragma mark Store methods

- (void)storeObject:(NSObject <BuriSupport> *)object
{
	if ([object class] != _usedClass) {
		[NSException raise:@"Storing different object type" format:@"the object type you are trying to store, should be of the %@ class", NSStringFromClass(_usedClass)];
	}

	BuriWriteObject *wo = [[BuriWriteObject alloc] initWithBuriObject:object];

    /*BuriWriteObject *currObject = [_buri getObject:[self prefixKey:[wo key]]];
    
    if (currObject)
    {
        [self deleteWriteObject:currObject];
    }*/
    
    [self storeBinaryIndexesForWriteObject:wo];
    [self storeNumericIndexesForWriteObject:wo];
	
    [_buri putObject:wo forKey:[self prefixKey:[wo key]]];
}

- (void)storeBinaryIndexesForWriteObject:(BuriWriteObject *)wo
{
	NSArray *binaryIndexes = [wo binaryIndexes];

	for (BuriBinaryIndex *index in binaryIndexes) {
        [self initExactBinaryIndexPointerForIndexKey:[index key] value:[index value]];
		NSString *indexKey = [self indexKeyForBinaryIndex:index writeObject:wo];
		[_buri putObject:[wo key] forKey:indexKey];
	}
}

- (void)storeNumericIndexesForWriteObject:(BuriWriteObject *)wo
{
	NSArray *numericIndexes = [wo numericIndexes];

	for (BuriNumericIndex *index in numericIndexes) {
        [self initExactNumericIndexPointerForIndexKey:[index key] value:[index value]];
        [self initRangeNumericIndexPointerForIndexKey:[index key]];
        
		NSString *indexKey = [self indexKeyForNumericIndex:index writeObject:wo];
		[_buri putObject:[wo key] forKey:indexKey];
	}
}

#pragma mark -
#pragma mark Delete methods

- (void)deleteObjectForKey:(NSString *)key
{
	BuriWriteObject *wo = [_buri getObject:[self prefixKey:key]];

	if (wo) {
		[self deleteWriteObject:wo];
	}
}

- (void)deleteObject:(NSObject <BuriSupport> *)object
{
	if ([object class] != _usedClass) {
		[NSException raise:@"Deleting different object type" format:@"the object type you are trying to store of type: %@, should be of the %@ class", NSStringFromClass([object class]), NSStringFromClass(_usedClass)];
	}

	BuriWriteObject *wo = [[BuriWriteObject alloc] initWithBuriObject:object];
    
	[self deleteWriteObject:wo];
}

- (void)deleteWriteObject:(BuriWriteObject *)wo
{
	[self deleteBinaryIndexesForWriteObject:wo];
	[self deleteNumericIndexesForWriteObject:wo];
	[_buri deleteObject:[self prefixKey:[wo key]]];
}

- (void)deleteBinaryIndexesForWriteObject:(BuriWriteObject *)wo
{
	NSArray *binaryIndexes = [wo binaryIndexes];

	for (BuriBinaryIndex *index in binaryIndexes) {
		NSString *indexKey = [self indexKeyForBinaryIndex:index writeObject:wo];
		[_buri deleteObject:indexKey];
	}
}

- (void)deleteNumericIndexesForWriteObject:(BuriWriteObject *)wo
{
	NSArray *numericIndexes = [wo numericIndexes];

	for (BuriNumericIndex *index in numericIndexes) {
		NSString *indexKey = [self indexKeyForNumericIndex:index writeObject:wo];
		[_buri deleteObject:indexKey];
	}
}

- (void)deleteAllObjects
{
    [[self allObjects] enumerateObjectsUsingBlock:^(NSObject <BuriSupport> *obj, NSUInteger idx, BOOL *stop) {
        [self deleteObject:obj];
    }];
}

@end