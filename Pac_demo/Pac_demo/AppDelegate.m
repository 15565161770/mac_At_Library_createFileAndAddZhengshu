//
//  AppDelegate.m
//  Pac_demo
//
//  Created by 仝兴伟 on 2017/7/4.
//  Copyright © 2017年 仝兴伟. All rights reserved.
//

#import "AppDelegate.h"
#import "SocketManger.h"
#define kUrl

#import "Help.h"
@interface AppDelegate ()

{
    long long number;
    NSString *str;
}

@property (weak) IBOutlet NSWindow *window;


@end

@implementation AppDelegate


- (NSString *)baseRequestURL {
    if (!self.baseUrl) {
        NSString *plistPath = [[NSBundle mainBundle] pathForResource: @"MyPlist" ofType:@"plist"];
        NSMutableDictionary * dic = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
        self.baseUrl = dic[@"Request_URL"];
    }
    return self.baseUrl;
}


- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
//    return [NSString stringWithFormat: @"%@%@",  [(AppDelegate *)[UIApplication sharedApplication].delegate baseRequestURL], self.url ? self.url : @""];
//    [(AppDelegate *)[NSApplication sharedApplication].delegate baseRequestURL];
//    
//    
//    NSLog(@"%@", [(AppDelegate *)[NSApplication sharedApplication].delegate baseRequestURL]);
//    [[SocketManger sharedSocketManger]startListen];
    
    /*
    number = 9223372036854775807;
//    number = 9022;
    UInt32 hight = (UInt32)(number>> 32);
    UInt32 low =  (UInt32)number;
    NSLog(@"%d ---- %d", hight, low);

    str = @"9223372036854775807";
 long long value = [str longLongValue];
//    NSLog(@"long value: %qi", value);
    UInt32 hight1 = (UInt32)(value>> 32);
    UInt32 low1 =  (UInt32)value;
    NSLog(@"%d ---- %d", hight1, low1);
     */
    
    
    [Help install];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
