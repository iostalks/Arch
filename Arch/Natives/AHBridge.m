//
//  AHBridge.m
//  Arch
//
//  Created by Smallfly on 2019/5/15.
//  Copyright © 2019 Smallfly. All rights reserved.
//

#import "AHBridge.h"
#import <JavaScriptCore/JavaScriptCore.h>

#import "AHBridgeMethod.h"
#import "AHBridgeModule.h"
#import "AHModuleData.h"

#import "AHJSExecutor.h"
#import "RCTUtils.h"
#import "AHConvert.h"
/**
 * Must be kept in sync with `MessageQueue.js`.
 * JS 端存方法调用信息的
 */
typedef NS_ENUM(NSUInteger, RCTBridgeFields) {
    RCTBridgeFieldRequestModuleIDs = 0,
    RCTBridgeFieldMethodIDs,
    RCTBridgeFieldParams,
    RCTBridgeFieldCallID,
};

static NSMutableArray<Class> *AHModuleClasses;
void AHRegisterModule(Class moduleClass) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        AHModuleClasses = [NSMutableArray new];
    });
    [AHModuleClasses addObject:moduleClass];
}

// class -> module string name
NSString *AHBridgeModuleNameForClass(Class cls) {
    NSString *name = [cls moduleName];
    if (name.length == 0) {
        name = NSStringFromClass(cls);
    }
    return name;
}

@interface AHBridge ()
@property (nonatomic, strong) NSArray<AHModuleData *> *moduleDataByID;
@property (nonatomic, strong) AHJSExecutor *jsExecutor;
@end

@implementation AHBridge

#pragma mark - Public

- (NSArray<Class> *)moduleClasses {
    return [AHModuleClasses copy];
}

- (NSString *)nameForModuleClass:(Class)moduleClass {
    return AHBridgeModuleNameForClass(moduleClass);
}

- (NSString *)moduleConfig {
    NSMutableArray *config = [NSMutableArray new];
    for (AHModuleData *data in _moduleDataByID) {
        [config addObject:data.config];
    }
    return RCTJSONStringify(@{
      @"remoteModuleConfig": config
    }, NULL);
}

#pragma makr - Private

- (void)start {
    if (_jsExecutor) return;
    _jsExecutor = [[AHJSExecutor alloc] initWidthBridge:self];
    
    dispatch_queue_t bridgeQueue = dispatch_queue_create("com.arch.AHBridge", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t group = dispatch_group_create();

    // 初始化模块信息列表
    NSMutableArray<AHModuleData *> *moduleDataById = [NSMutableArray new];
    for (Class cls in AHModuleClasses) {
        AHModuleData *moduleData = [[AHModuleData alloc] initWithModuleClass:cls bridge:self];
        [moduleDataById addObject:moduleData];
    }
    _moduleDataByID = [moduleDataById copy];
    
    dispatch_group_enter(group);
    dispatch_async(bridgeQueue, ^{
        // 将暴露给 JS 的模块注入 JS 环境
        NSString *config = [self moduleConfig];
        [self->_jsExecutor injectJSONText:config asGlobalObjectNamed:@"__batchedBridgeConfig" callback:^(NSError * _Nullable error) {}];
        dispatch_group_leave(group);
    });
    
    
    // 执行 JS 代码
    dispatch_group_notify(group, bridgeQueue, ^{
        NSArray *JSFileNames = @[@"Arch",/* @"BatchedBridge", @"NativeModules", @"Arch"*/];
        for (NSString *fileName in JSFileNames) {
            NSString *jsPath = [[NSBundle bundleForClass:[self class]] pathForResource:fileName ofType:@"js"];
           NSString *jsScript = [[NSString alloc] initWithData:[[NSFileManager defaultManager] contentsAtPath:jsPath] encoding:NSUTF8StringEncoding];
            [self->_jsExecutor executeApplicationScript:jsScript onComplete:^(NSError * _Nullable error) { }];
        }
    });
}

#pragma mark - Native Call JS

// 同步调用 Only JS Thread
- (JSValue *)synCallJSModule:(NSString *)module
                 method:(NSString *)method
                   args:(NSArray *)args
                  error:(NSError * _Nullable __autoreleasing *)error {
    __block JSValue *jsResult = nil;
    [_jsExecutor callFunctionOnModule:module method:method arguments:args jsValueCallback:^(JSValue*  _Nullable result, NSError * _Nullable jsError) {
        if (error) {
            *error = jsError;
        }
        
        // result 是一个数组，见 MessageQueue 中的 callFunctionReturnResultAndFlushedQueue 方法
        JSValue *length = result[@"length"];
        if ([length toInt32] != 2) {
            NSLog(@"ERROR: 同步调用返回值有误 %@:%@", module, method);
            return;
        }
        
        // 第一个参数是实际的返回值
        jsResult = [result valueAtIndex:0];
        
        // 第二个参数是消息队列中未执行的 Native 调用
        NSArray *nativeCallModules = [[result valueAtIndex:1] toArray];
        if (!nativeCallModules.count) {
            [self handleBuffer:nativeCallModules];
        }
    }];
    return jsResult;
}

// 异步调用
- (void)asynCallJSModule:(NSString *)module
                  method:(NSString *)method
                    args:(NSArray *)args
              completion:(dispatch_block_t)completion {
    [_jsExecutor callFunctionOnModule:module method:method arguments:args callback:^(id result, NSError *error) {
        [self handleBuffer:result];
    }];
}

// 执行 JS Callback
- (void)invokeJSCallback:(NSNumber *)callbackId arguments:(NSArray *)args {
    [_jsExecutor invokeCallbackID:callbackId arguments:args callback:^(id  _Nullable result, NSError * _Nullable jsError) {
       [self handleBuffer:result];
    }];
}

#pragma mark - JS call Native

- (void)handleBuffer:(id)buffer {
    if (buffer && buffer != (id)kCFNull) {
        NSArray *requestsArray = [AHConvert NSArray:buffer];
        if (requestsArray.count < RCTBridgeFieldParams) {
            NSLog(@"ERROR: JS 参数结构错误");
            return;
        }
        NSArray<NSNumber *> *moduleIDs = requestsArray[RCTBridgeFieldRequestModuleIDs];
        NSArray<NSNumber *> *methodIDs = requestsArray[RCTBridgeFieldMethodIDs];
        NSArray<NSArray *> *paramsArrays = requestsArray[RCTBridgeFieldParams];
        
        int64_t callbackID = -1;
        if (requestsArray.count > 3) {
            callbackID = [requestsArray[RCTBridgeFieldCallID] longLongValue];
        }

        if (moduleIDs.count <= 0 || methodIDs.count <= 0 || paramsArrays.count <= 0) {
            NSLog(@"ERROR: 参数错误");
            return;
        }
        [moduleIDs enumerateObjectsUsingBlock:^(NSNumber * _Nonnull moduleID, NSUInteger idx, BOOL * _Nonnull stop) {
            AHModuleData *moduleData = self->_moduleDataByID[moduleID.integerValue];
            // 该模块指定在哪个线程执行
            dispatch_queue_t queue = moduleData.methodQueue;
            dispatch_block_t block = ^{
                [self asycCallNativeModule:moduleID.integerValue method:methodIDs[idx].integerValue params:paramsArrays[idx]];
            };
            
//            if (queue == self->_jsExecutor.JSThread) {
//                block();
//            } else {
                dispatch_async(queue, block);
//            }
        }];
    } else {
        NSLog(@"ERROR: buffer 为空");
    }
}

// 异步 JS 调用  OC
- (id)asycCallNativeModule:(NSUInteger)moduleId method:(NSUInteger)methodID params:(NSArray *)params {
    AHModuleData *moduleData = self->_moduleDataByID[moduleId];
    id<AHBridgeMethod> method = moduleData.methods[methodID];
    [method invokeWithBridge:self module:moduleData.instance arguments:params];
    return nil;
}

@end
