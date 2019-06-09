//
//  AHConvert.m
//  Arch
//
//  Created by Smallfly on 2019/5/30.
//  Copyright © 2019 Smallfly. All rights reserved.
//

#import "AHConvert.h"
#import <objc/message.h>

@implementation AHConvert

#define RCT_JSON_CONVERTER(type)           \
+ (type *)type:(id)json                    \
{                                          \
if ([json isKindOfClass:[type class]]) { \
return json;                           \
} else if (json) {                       \
    NSLog(@"ERROR CONVERT: %@", json);       \
}                                        \
return nil;                              \
}

RCT_JSON_CONVERTER(NSArray)
RCT_JSON_CONVERTER(NSDictionary)
RCT_JSON_CONVERTER(NSString)
RCT_JSON_CONVERTER(NSNumber)

NSArray<NSNumber *> *NSNumberArray(NSArray<NSNumber *> *array) {
    return array;
}

NSArray *RCTConvertArrayValue(SEL type, id json)
{
    __block BOOL copy = NO;
    __block NSArray *values = json = [AHConvert NSArray:json];
    [json enumerateObjectsUsingBlock:^(id jsonValue, NSUInteger idx, __unused BOOL *stop) {
        id value = ((id(*)(Class, SEL, id))objc_msgSend)([AHConvert class], type, jsonValue);
        if (copy) {
            if (value) {
                [(NSMutableArray *)values addObject:value];
            }
        } else if (value != jsonValue) {
            // Converted value is different, so we'll need to copy the array
            values = [[NSMutableArray alloc] initWithCapacity:values.count];
            for (NSUInteger i = 0; i < idx; i++) {
                [(NSMutableArray *)values addObject:json[i]];
            }
            if (value) {
                [(NSMutableArray *)values addObject:value];
            }
            copy = YES;
        }
    }];
    return values;
}

@end
