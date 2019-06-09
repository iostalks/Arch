//
//  AppDelegate.m
//  Arch
//
//  Created by Smallfly on 2019/5/15.
//  Copyright © 2019 Smallfly. All rights reserved.
//

#import "AppDelegate.h"
#import "AHBridge.h"
#import <JavaScriptCore/JavaScriptCore.h>

@interface AppDelegate ()
@end

@implementation AppDelegate {
    NSThread *_thread;
    AHBridge *_bridge;
}

- (void)runRunLoop {
    NSLog(@"run loop");
    @autoreleasepool {
        // 设置当前线程名称
//        pthread_setname_np([NSThread currentThread].name.UTF8String);
        
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

- (void)testJSCore {
    JSContext *content = [[JSContext alloc] init];
    content[@"console"][@"log"] = ^() {
        NSLog(@"hhh");
    };
    [content evaluateScript:@"console.log('1')"];
}

- (id)play:(NSNumber *)number {
    NSLog(@"play: %ld", number.integerValue);
    return [NSString stringWithFormat:@"return: %ld", number.integerValue];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.

//    [self testJSCore];
    _bridge = [[AHBridge alloc] init];
    [_bridge start];
    
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
