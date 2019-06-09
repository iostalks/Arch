//
//  AHModuleData.h
//  Arch
//
//  Created by Smallfly on 2019/5/15.
//  Copyright © 2019 Smallfly. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol AHBridgeModule;
@protocol AHBridgeMethod;
@class AHBridge;

NS_ASSUME_NONNULL_BEGIN


@interface AHModuleData : NSObject

@property (nonatomic, strong, readonly) Class moduleClass;
@property (nonatomic, copy, readonly) NSString* name;

// 需要时自动实例对象，用于执行实例方法
@property (nonatomic, strong, readonly) id<AHBridgeModule> instance;

@property (nonatomic, strong) NSArray<id<AHBridgeMethod>> *methods;
@property (nonatomic, readonly) NSArray* config;

// 该类调用方法所在的线程，默认是主线程
@property (nonatomic, strong, readonly) dispatch_queue_t methodQueue;

- (instancetype)initWithModuleClass:(Class)moduleClass bridge:(AHBridge *)bridge;

@end

NS_ASSUME_NONNULL_END
