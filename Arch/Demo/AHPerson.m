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

AH_EXPORT_METHOD(run) {
    NSLog(@"******* JS Call Native *******");
    NSLog(@"Running man.");
    NSLog(@"******************************");
}

@end
