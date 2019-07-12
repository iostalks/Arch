//
//  AHPerson.m
//  Arch
//
//  Created by Smallfly on 2019/5/15.
//  Copyright © 2019 Smallfly. All rights reserved.
//

#import "AHPerson.h"

@implementation AHPerson
+ (void)load {
    AHRegisterModule(self);
}

+ (NSString *)moduleName {
    return @"Person";
}

- (NSDictionary<NSString *,id> *)constantsToExport {
    return @{ @"name": @"Smallfly", @"age": @"18" };
}

AH_EXPORT_METHOD(run) {
    NSLog(@"******* JS Call Native *******");
    NSLog(@"Running souche man.");
    NSLog(@"******************************");
}

@end
