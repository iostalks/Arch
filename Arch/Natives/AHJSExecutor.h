//
//  AHJSExecutor.h
//  Arch
//
//  Created by Smallfly  on 2019/5/17.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

@class AHBridge;

typedef void (^AHJSCompletionBlock)(NSError * _Nullable jsError);
typedef void (^AHJSCallbackBlock)(id _Nullable result, NSError * _Nullable jsError);
typedef void (^AHJSValueCallback)(JSValue * _Nullable result, NSError * _Nullable jsError);

NS_ASSUME_NONNULL_BEGIN

@interface AHJSExecutor : NSObject

@property (nonatomic, readonly) JSContext *context;
@property (nonatomic, readonly) NSThread *JSThread;
@property (nonatomic, weak) AHBridge *bridge;

- (instancetype)initWidthBridge:(AHBridge *)bridge;

// 注入 objectName 属性到 global
- (void)injectJSONText:(NSString *)script
   asGlobalObjectNamed:(NSString *)objectName
              callback:(AHJSCompletionBlock)onComplete;

// OC 调用 JS，异步返回结果
// 这么的 module 并不一定是 OC 暴露给 JS 的，也可能仅在 JS 端定义的
- (void)callFunctionOnModule:(NSString *)module
                      method:(NSString *)method
                   arguments:(NSArray *)args
                    callback:(AHJSCallbackBlock)onComplete;

// OC 调用 JS，在 Callback 中同步返回结果
- (void)callFunctionOnModule:(NSString *)module
                      method:(NSString *)method
                   arguments:(NSArray *)args
             jsValueCallback:(AHJSValueCallback)onComplete;

// OC 执行 JS callback 回调
- (void)invokeCallbackID:(NSNumber *)cbID
               arguments:(NSArray *)args
                callback:(AHJSCallbackBlock)onComplete;

// 执行 JSBundle
- (void)executeApplicationScript:(NSString *)script
                      onComplete:(AHJSCompletionBlock)onComplete;
@end

NS_ASSUME_NONNULL_END
