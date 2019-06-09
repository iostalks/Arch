//
//  AHModuleProtocol.h
//  Arch
//
//  Created by Smallfly on 2019/5/15.
//

#import <Foundation/Foundation.h>
#import "RCTDefines.h"

/**
 所有自定义组件想要暴露给 JS 都需要遵循 AHBridgeModule 协议
*/

@class AHBridge;

NS_ASSUME_NONNULL_BEGIN

#define AH_EXTERN_RMAP_METHOD(js_name, method) \
    + (NSArray<NSString *> *)RCT_CONCAT(__ah_export__, \
      RCT_CONCAT(js_name, RCT_CONCAT(__LINE__, __COUNTER__))) { \
      return @[@#js_name, @#method]; \
    }

// 每个导出给 JS 的方法，都会关联一个附属的方法，用来获取字符串类名和方法名
// 导出给 JS 的方法都没有返回值，也就决定了 JS 调用 OC 无法同步获取返回值
// js_name 在 js 端的方法名，如果会空会根据 OC 的 api 进行特定格式转换

#define AH_REMAP_METHOD(js_name, method) \
    AH_EXTERN_RMAP_METHOD(js_name, method) \
    - (void)method

#define AH_EXPORT_METHOD(method) \
    AH_REMAP_METHOD(, method)



@protocol AHBridgeModule <NSObject>

RCT_EXTERN void AHRegisterModule(Class);

+ (NSString *)moduleName;

@optional

@property (nonatomic, strong, readonly) AHBridge *bridge;

// 暴露给 JS 的常量，只会在初始化的时候执行一次
- (NSDictionary<NSString *, id> *)constantsToExport;

@end

NS_ASSUME_NONNULL_END
