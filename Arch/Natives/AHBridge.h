//
//  AHBridge.h
//  Arch
//
//  Created by Smallfly on 2019/5/15.
//  Copyright © 2019 Smallfly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface AHBridge : NSObject

@property (nonatomic, strong, readonly) NSArray<Class> *moduleClasses;

// 启动 Bridge 引擎
- (void)start;

// OC 异步调用 JS，线程安全
//- (void)enqueueJSCall:(NSString *)module method:(NSString *)method args:(NSArray *)args completion:(dispatch_block_t)completion
- (void)asynCallJSModule:(NSString *)module method:(NSString *)method args:(NSArray *)args completion:(dispatch_block_t)completion;

// OC 同步调用 JS，需要在 JSBundle 加载成功后才能使用
// **该方法只能在 JS 线程调用**
//- (JSValue *)callFunctionOnModule:(NSString *)module method:(NSString *)method args:(NSArray *)args error:(NSError **)error;
- (JSValue *)synCallJSModule:(NSString *)module method:(NSString *)method args:(NSArray *)args error:(NSError **)error;

// OC 执行 JS 的 callback，线程安全
- (void)invokeJSCallback:(NSNumber *)callbackId;

// JS 异步调用 OC，为什么要暴露出来？
// ** 只能异步调用 **
- (id)asycCallNativeModule:(NSUInteger)moduleId method:(NSUInteger)methodID params:(NSArray *)params;
//- (id)callNativeModule:(NSUInteger)moduleID method:(NSUInteger)methodID params:(NSArray *)params;
- (void)handleBuffer:(id)calls;

/////////////
// Accessory
////////////

// 获取 module 的实例
// 导出给 JS 端的只有类名，OC 端要创建对应的实例，在 JS 调用 OC 时触发实例方法的调用
//- (id)instanceForModuleName:(NSString *)moduleName;
//- (id)instanceForModuleClass:(Class)moduleClass;

// 根据 Class 获取导出名
- (NSString *)nameForModuleClass:(Class)moduleClass;

@end

NS_ASSUME_NONNULL_END
