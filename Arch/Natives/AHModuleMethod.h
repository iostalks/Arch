//
//  AHModuleMethod.h
//  Arch
//
//  Created by Smallfly on 2019/5/15.
//

#import <Foundation/Foundation.h>
#import "AHBridgeMethod.h"

typedef NS_ENUM(NSUInteger, RCTNullability) {
    RCTNullabilityUnspecified,
    RCTNullable,
    RCTNonnullable,
};

@interface RCTMethodArgument : NSObject

@property (nonatomic, copy, readonly) NSString * _Nullable type;
@property (nonatomic, readonly) RCTNullability nullability;
@property (nonatomic, readonly) BOOL unused;

@end


NS_ASSUME_NONNULL_BEGIN

@interface AHModuleMethod : NSObject<AHBridgeMethod>

@property (nonatomic, readonly) Class moduleClass;
@property (nonatomic, readonly) SEL selector;

- (instancetype)initWithMethodSignature:(NSString *)objCMethodName
                           JSMethodName:(NSString *)JSMethodName
                            moduleClass:(Class)moduleClass;

@end

NS_ASSUME_NONNULL_END
