//
//  AHModuleMethod.m
//  Arch
//
//  Created by Smallfly on 2019/5/15.
//

#import "AHModuleMethod.h"
#import "AHPerson.h"

@interface AHModuleMethod ()
@property (nonatomic, copy) NSString *methodSignature;
@end

@implementation AHModuleMethod

@synthesize JSMethodName = _JSMethodName;
@synthesize type = _type;

@synthesize selector = _selector;
@synthesize moduleClass = _moduleClass;

- (instancetype)initWithMethodSignature:(NSString *)methodSignature
                           JSMethodName:(NSString *)JSMethodName
                            moduleClass:(Class)moduleClass {
    if (self = [super init]) {
        _moduleClass = moduleClass;
        _methodSignature = [methodSignature copy];
        _JSMethodName = [JSMethodName copy];
    }
    return self;
}

// 处理参数，并执行方法
// 只处理没有参数的情况（包括 callback），处理参数巨复杂，这个 demo 主要是为了理解通信，有没有参数并不重要。
- (void)invokeWithBridge:(AHBridge *)bridge module:(id)module arguments:(NSArray *)arguments {
    SEL sel = NSSelectorFromString(_methodSignature);// 因为不考虑参数，所以直接用 string 转 sel
    NSMethodSignature *signature = [_moduleClass instanceMethodSignatureForSelector:sel];
    if (!signature) {
        NSLog(@"EROOR: %@ 方法签名为空", _methodSignature);
        return;
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = sel;
    invocation.target = module;

    [invocation invoke];
}

#pragma mark - Getter and Setter

- (NSString *)JSMethodName {
    NSString *methodName = _JSMethodName;
    if (methodName.length == 0) {
        methodName = _methodSignature;
        NSRange colonRange = [methodName rangeOfString:@":"];
        if (colonRange.location != NSNotFound) {
            methodName = [methodName substringToIndex:colonRange.location];
        }
        methodName = [methodName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    return methodName;
}

@end
