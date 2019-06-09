//
//  AHMethodProtocol.h
//  Arch
//
//  Created by Smallfly on 2019/5/15.
//  Copyright © 2019 Smallfly. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AHFucntionType) {
    AHFucntionTypeNormal, // 异步
    AHFucntionTypePromise,
    AHFucntionTypeSync,
};

NS_ASSUME_NONNULL_BEGIN

@class AHBridge;

@protocol AHBridgeMethod <NSObject>
@property (nonatomic, copy, readonly) NSString *JSMethodName;
@property (nonatomic, readonly) AHFucntionType type;

// 触发 method 的调用, arguments 包含参数以及 callback
- (void)invokeWithBridge:(AHBridge *)bridge module:(id)module arguments:(NSArray *)arguments;

@end

NS_ASSUME_NONNULL_END
