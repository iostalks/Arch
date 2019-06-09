//
//  AHConvert.h
//  Arch
//
//  Created by Smallfly on 2019/5/30.
//  Copyright © 2019 Smallfly. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AHConvert : NSObject
+ (NSArray *)NSArray:(id)json;
+ (NSDictionary *)NSDictionary:(id)json;
+ (NSString *)NSString:(id)json;
+ (NSNumber *)NSNumber:(id)json;
@end

NS_ASSUME_NONNULL_END
