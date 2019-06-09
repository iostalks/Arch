//
//  AHModuleMethod.m
//  Arch
//
//  Created by Smallfly on 2019/5/15.
//

#import "AHModuleMethod.h"
#import "RCTParserUtils.h"
#import "AHPerson.h"

//typedef BOOL (^RCTArgumentBlock)(RCTBridge *, NSUInteger, id);

@implementation RCTMethodArgument

- (instancetype)initWithType:(NSString *)type
                 nullability:(RCTNullability)nullability
                      unused:(BOOL)unused
{
    if (self = [super init]) {
        _type = [type copy];
        _nullability = nullability;
        _unused = unused;
    }
    return self;
}

@end


// returns YES if the selector ends in a colon (indicating that there is at
// least one argument, and maybe more selector parts) or NO if it doesn't.
static BOOL RCTParseSelectorPart(const char **input, NSMutableString *selector)
{
    NSString *selectorPart;
    if (RCTParseIdentifier(input, &selectorPart)) {
        [selector appendString:selectorPart];
    }
    RCTSkipWhitespace(input);
    if (RCTReadChar(input, ':')) {
        [selector appendString:@":"];
        RCTSkipWhitespace(input);
        return YES;
    }
    return NO;
}

static BOOL RCTParseUnused(const char **input)
{
    return RCTReadString(input, "__unused") ||
    RCTReadString(input, "__attribute__((unused))");
}

static RCTNullability RCTParseNullability(const char **input)
{
    if (RCTReadString(input, "nullable")) {
        return RCTNullable;
    } else if (RCTReadString(input, "nonnull")) {
        return RCTNonnullable;
    }
    return RCTNullabilityUnspecified;
}

static RCTNullability RCTParseNullabilityPostfix(const char **input)
{
    if (RCTReadString(input, "_Nullable")) {
        return RCTNullable;
    } else if (RCTReadString(input, "_Nonnull")) {
        return RCTNonnullable;
    }
    return RCTNullabilityUnspecified;
}

// returns YES if execution is safe to proceed (enqueue callback invocation), NO if callback has already been invoked
//static BOOL RCTCheckCallbackMultipleInvocations(BOOL *didInvoke) {
//    if (*didInvoke) {
////        RCTFatal(RCTErrorWithMessage(@"Illegal callback invocation from native module. This callback type only permits a single invocation from native code."));
//        return NO;
//    } else {
//        *didInvoke = YES;
//        return YES;
//    }
//}

// 从 AH_EXPORT_METHOD 提供的方法签名中，提取参数
SEL RCTParseMethodSignature(NSString *, NSArray<RCTMethodArgument *> **);
SEL RCTParseMethodSignature(NSString *methodSignature, NSArray<RCTMethodArgument *> **arguments)
{
    const char *input = methodSignature.UTF8String;
    RCTSkipWhitespace(&input);
    
    NSMutableArray *args;
    NSMutableString *selector = [NSMutableString new];
    while (RCTParseSelectorPart(&input, selector)) {
        if (!args) {
            args = [NSMutableArray new];
        }
        
        // Parse type
        if (RCTReadChar(&input, '(')) {
            RCTSkipWhitespace(&input);
            
            BOOL unused = RCTParseUnused(&input);
            RCTSkipWhitespace(&input);
            
            RCTNullability nullability = RCTParseNullability(&input);
            RCTSkipWhitespace(&input);
            
            NSString *type = RCTParseType(&input);
            RCTSkipWhitespace(&input);
            if (nullability == RCTNullabilityUnspecified) {
                nullability = RCTParseNullabilityPostfix(&input);
            }
            [args addObject:[[RCTMethodArgument alloc] initWithType:type
                                                        nullability:nullability
                                                             unused:unused]];
            RCTSkipWhitespace(&input);
            RCTReadChar(&input, ')');
            RCTSkipWhitespace(&input);
        } else {
            // Type defaults to id if unspecified
            [args addObject:[[RCTMethodArgument alloc] initWithType:@"id"
                                                        nullability:RCTNullable
                                                             unused:NO]];
        }
        
        // Argument name
        RCTParseIdentifier(&input, NULL);
        RCTSkipWhitespace(&input);
    }
    
    *arguments = [args copy];
    return NSSelectorFromString(selector);
}


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
