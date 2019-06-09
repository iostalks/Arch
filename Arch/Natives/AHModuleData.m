//
//  AHModuleData.m
//  Arch
//
//  Created by Smallfly on 2019/5/15.
//  Copyright © 2019 Smallfly. All rights reserved.
//

#import "AHModuleData.h"

#import <objc/runtime.h>
#import "RCTUtils.h"

#import "AHBridge.h"

#import "AHModuleMethod.h"
#import "AHBridgeModule.h"

@implementation AHModuleData {
    __weak AHBridge *_bridge;
    id _instance;
    NSDictionary<NSString *, id> *_constantsToExport;
}

- (instancetype)initWithModuleClass:(Class)moduleClass bridge:(nonnull AHBridge *)bridge {
    if (self = [super init]) {
        _bridge = bridge;
        _moduleClass = moduleClass;
        [self setup];
    }
    return self;
}

- (void)setup {
}

- (id)instance {
    return _instance;
}

- (NSString *)name {
    return [_bridge nameForModuleClass:_moduleClass];
}

- (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
}

- (NSArray<id<AHBridgeMethod>> *)methods {
    if (!_methods) {
        NSMutableArray <id<AHBridgeMethod>> *moduleMethods = [NSMutableArray new];
        
        unsigned int count;
        Class cls = _moduleClass;
        // 遍历继承体系下所有暴露给的方法
        while (cls && [NSObject class] != cls && [NSObject class] != cls) {
            Method *methods = class_copyMethodList(object_getClass(cls), &count);
            for (unsigned int i = 0; i < count; ++i) {
                Method method = methods[i];
                SEL sel = method_getName(method);
                if ([NSStringFromSelector(sel) hasPrefix:@"__ah_export__"]) {
                    IMP imp = method_getImplementation(method);
                    NSArray<NSString*> *entries = ((NSArray<NSString *> *(*)(id, SEL))imp)(_moduleClass, sel);
                    id<AHBridgeMethod> moduleMethod = [[AHModuleMethod alloc]
                                                         initWithMethodSignature:entries[1]
                                                         JSMethodName:entries[0]
                                                         moduleClass:_moduleClass];
                    [moduleMethods addObject:moduleMethod];
                }
            }
            
            free(methods);
            cls = [cls superclass];
        }
        
        _methods = [moduleMethods copy];
    }
    return _methods;
}

- (void)gatherConstants {
    if (_constantsToExport) return;
    // 确保 instance 已经实例化
    _instance = [_moduleClass new];
    // 为实例设置 bridge 属性
//    @try {
//        [_instance setValue:_bridge forKey:@"bridge"];
//    }
//    @catch (NSException *excetion) {
//        NSLog(@"ERROR: %@ 没有设置 bridge 的方法", self.name);
//    }

    // 设置实例方法调用的线程...
    
    if ([_instance respondsToSelector:@selector(constantsToExport)]) {
        self->_constantsToExport = [self->_instance constantsToExport];
    }
}

- (NSArray *)config {
    [self gatherConstants];
    // __block why?
    NSDictionary *constants = _constantsToExport;
    _constantsToExport = nil;
    if (!self.methods.count && !constants) {
        return (id)kCFNull;
    }
    
    NSMutableArray<NSString *>* methods = self.methods.count ? [NSMutableArray new] : (id)kCFNull;
    // 所有 promise 方法 ID
    NSMutableArray<NSNumber *>* promiseMethods = (id)kCFNull;
    // 所有同步方法 ID
    NSMutableArray<NSNumber *>* syncMethods = (id)kCFNull;
    
    for (AHModuleMethod *method in self.methods) {
        if (method.type == AHFucntionTypePromise) {
            if ((id)kCFNull == promiseMethods) {
                promiseMethods = [NSMutableArray new];
            }
            // methods.count 代表当前 method 在 methods 中的下标，用来代表方法 ID
            // ps: 挺巧妙的方法：》
            [promiseMethods addObject:@(methods.count)];
        } else if (method.type == AHFucntionTypeSync) {
            if ((id)kCFNull == promiseMethods) {
                syncMethods = [NSMutableArray new];
            }
            [syncMethods addObject:@(methods.count)];
        }
        [methods addObject:method.JSMethodName];
    }
    
    return @[
        self.name,
        RCTNullIfNil(constants),
        methods, // 所有方法，包括 promiseMethods 和 syncMethods
        promiseMethods,
        syncMethods,
    ];
}
@end
