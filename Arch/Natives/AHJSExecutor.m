//
//  AHJSExecutor.m
//  Arch
//
//  Created by Smallfly on 2019/5/17.
//  Copyright © 2019 Smallfly. All rights reserved.
//

#import "AHJSExecutor.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import <pthread.h>
#import "AHBridge.h"

@implementation AHJSExecutor {
    JSValueRef _batchedBridgeRef;
}

@synthesize context = _context;
@synthesize JSThread = _JSThread;

- (instancetype)initWidthBridge:(AHBridge *)bridge {
    if (self = [super init]) {
        _context = [[JSContext alloc] init];
        _JSThread = newJavaScriptThread();
        _bridge = bridge;
        
        [self setup];
    }
    return self;
}

- (void)setup {
    [self executeBlockOnJavaScriptQueue:^{
        // 提供给 JS 直接调用 OC 的接口
        __weak AHJSExecutor *weakSelf = self;
        self->_context[@"nativeFlushQueueImmediate"] = ^(NSArray<NSArray *> *calls) {
            AHJSExecutor *strongSelf = weakSelf;
            [strongSelf->_bridge handleBuffer:calls];
        };
        self->_context[@"console"][@"log"] = ^(JSValue *v) {
            NSLog(@"CNM: %@", v);
        };
    }];
}

static NSThread* newJavaScriptThread() {
    NSThread *thread = [[NSThread alloc] initWithTarget:[AHJSExecutor class] selector:@selector(runRunLoopThread) object:nil];
    thread.name = @"com.arch.javascript";
    thread.qualityOfService = NSOperationQualityOfServiceUserInteractive;
    [thread start];
    return thread;
}

+ (void)runRunLoopThread {
    @autoreleasepool {
        // 设置当前线程名称
        pthread_setname_np([NSThread currentThread].name.UTF8String);
        
        // Set up a dummy runloop source to avoid spinning
        CFRunLoopSourceContext noSpinCtx = {0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
        CFRunLoopSourceRef noSpinSource = CFRunLoopSourceCreate(NULL, 0, &noSpinCtx);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), noSpinSource, kCFRunLoopDefaultMode);
        CFRelease(noSpinSource);
        
        // run the run loop
        while (kCFRunLoopRunStopped != CFRunLoopRunInMode(kCFRunLoopDefaultMode, ((NSDate *)[NSDate distantFuture]).timeIntervalSinceReferenceDate, NO)) {
            NSAssert(NO, @"not reached assertion"); // runloop spun. that's bad.
        }
    }
}

- (void)executeBlockOnJavaScriptQueue:(dispatch_block_t)block {
    if ([NSThread currentThread] != _JSThread) {
        // performSelector 会同步在_JSThread线程执行 block
        // 不需要手动加锁，巧妙的设计。
        // _JSThread 开启了 RunLoop 所以能够被正常执行。
        [self performSelector:@selector(executeBlockOnJavaScriptQueue:)
                     onThread:_JSThread withObject:block waitUntilDone:NO];
    } else {
        block();
    }
}

/**
 注入属性对象到 global，在 AHBridge 初始化时调用

 @param script 注入JS对象
 @param objectName 对象名称
 @param onComplete 完成回调
 */
- (void)injectJSONText:(NSString *)script
   asGlobalObjectNamed:(NSString *)objectName
              callback:(AHJSCompletionBlock)onComplete {
    [self executeBlockOnJavaScriptQueue:^{
       
        JSGlobalContextRef ctx = self->_context.JSGlobalContextRef;
        JSStringRef execJSString = JSStringCreateWithCFString((__bridge CFStringRef)script);
        JSValueRef valueToInject = JSValueMakeFromJSONString(ctx, execJSString);
        JSStringRelease(execJSString);
        
        if (!valueToInject) {
            NSLog(@"ERROR: 注入脚本失败 %@", script);
            return;
        }
        JSObjectRef global = JSContextGetGlobalObject(ctx);
        JSStringRef JSName = JSStringCreateWithCFString((__bridge CFStringRef)objectName);
        JSObjectSetProperty(ctx, global, JSName, valueToInject, kJSPropertyAttributeNone, nil);
        JSStringRelease(JSName);
        
        // 忽略错误处理
        if (onComplete) {
            onComplete(nil);
        }
    }];
}

- (void)executeApplicationScript:(NSString *)script onComplete:(AHJSCompletionBlock)onComplete {
    [self executeBlockOnJavaScriptQueue:^{
        [self->_context evaluateScript:script];
    }];
}

- (void)_executeJSCall:(NSString *)method
             arguments:(NSArray *)args
          unwrapResult:(BOOL)unwrapResult
                    callback:(AHJSCallbackBlock)onComplete {
    [self executeBlockOnJavaScriptQueue:^{
        
        JSGlobalContextRef ctx =  self->_context.JSGlobalContextRef;
        
        JSValueRef errorJSRef = NULL;
        // JS 的 global.batchedBridge 对象定义了callFunctionReturnFlushedQueue和callFunctionReturnResultAndFlushedQueue方法
        // 供 Native 调用
        JSValueRef batchBridgeRef = self->_batchedBridgeRef;
        if (!self->_batchedBridgeRef) {
            JSStringRef batchedBridgeRefName = JSStringCreateWithUTF8CString("__batchedBridge");
            JSObjectRef globalObjectRef = JSContextGetGlobalObject(ctx);
            batchBridgeRef = JSObjectGetProperty(ctx, globalObjectRef, batchedBridgeRefName, &errorJSRef);
            JSStringRelease(batchedBridgeRefName);
            self->_batchedBridgeRef = batchBridgeRef;
        }
        
        // 构造调用 JS 的参数，并执行。
        JSValueRef resultJSRef = NULL;
        if (self->_batchedBridgeRef) {
            JSStringRef methodNameJSStringRef = JSStringCreateWithCFString((__bridge CFStringRef)method);
            JSValueRef methodRef = JSObjectGetProperty(ctx, (JSObjectRef)batchBridgeRef, methodNameJSStringRef, &errorJSRef);
            JSStringRelease(methodNameJSStringRef);
            
            if (methodRef) {
                JSValueRef jsArgs[args.count];
                for (NSUInteger i = 0; i < args.count; ++i) {
                    jsArgs[i] = [JSValue valueWithObject:args[i] inContext:self->_context].JSValueRef;
                }
                resultJSRef = JSObjectCallAsFunction(ctx, (JSObjectRef)methodRef, (JSObjectRef)batchBridgeRef, args.count, jsArgs, &errorJSRef);
            }
        } else {
            NSLog(@"ERROR: _batchedBridgeRef 为空");
        }
        
        id returnObj = nil;
        if (!errorJSRef) {
            JSValue *exception = [JSValue valueWithJSValueRef:errorJSRef inContext:self->_context];
            NSLog(@"Error Message : %@", exception[@"message"].toString);
        } else {
            if (JSValueGetType(ctx, resultJSRef) != kJSTypeNull) {
                JSValue *result = [JSValue valueWithJSValueRef:resultJSRef inContext:self->_context];
                returnObj = unwrapResult ? [result toObject] : result;
            }
        }
        // callback 返回执行结果，忽略错误消息
        onComplete(returnObj, nil);
    }];
}

- (void)_callFunctionOnModule:(NSString *)module
                       method:(NSString *)method
                    arguments:(NSArray *)args
                  returnValue:(BOOL)returnValue
                 unwrapResult:(BOOL)unwrapResult
                     callback:(AHJSCallbackBlock)onComplete {
    NSString *bridgeMethod = returnValue ? @"callFunctionReturnFlushedQueue" : @"callFunctionReturnResultAndFlushedQueue";
    [self _executeJSCall:bridgeMethod arguments:@[module, method, args] unwrapResult:unwrapResult callback:onComplete];
}

// 异步调用
- (void)callFunctionOnModule:(NSString *)module
                      method:(NSString *)method
                   arguments:(NSArray *)args
                    callback:(AHJSCallbackBlock)onComplete {
    [self _callFunctionOnModule:module method:method arguments:args returnValue:NO unwrapResult:NO callback:onComplete];
}

// 同步调用，callback 同步返回值
- (void)callFunctionOnModule:(NSString *)module
                      method:(NSString *)method
                   arguments:(NSArray *)args
                    jsValueCallback:(AHJSValueCallback)onComplete {
    [self _callFunctionOnModule:module method:method arguments:args returnValue:YES unwrapResult:YES callback:onComplete];
}

- (void)invokeCallbackID:(NSNumber *)cbID arguments:(NSArray *)args callback:(AHJSCallbackBlock)onComplete {
    [self _executeJSCall:@"invokeCallbackAndReturnFlushedQueue" arguments:@[cbID, args] unwrapResult:YES callback:onComplete];
}
@end
