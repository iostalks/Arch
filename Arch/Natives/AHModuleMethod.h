//
//  AHModuleMethod.h
//  Arch
//
//  Created by Smallfly on 2019/5/15.
//

#import <Foundation/Foundation.h>
#import "AHBridgeMethod.h"

NS_ASSUME_NONNULL_BEGIN

@interface AHModuleMethod : NSObject<AHBridgeMethod>

@property (nonatomic, readonly) Class moduleClass;
@property (nonatomic, readonly) SEL selector;

- (instancetype)initWithMethodSignature:(NSString *)objCMethodName
                           JSMethodName:(NSString *)JSMethodName
                            moduleClass:(Class)moduleClass;

@end

NS_ASSUME_NONNULL_END
