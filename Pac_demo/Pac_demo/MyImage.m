//
//  MyImage.m
//  Pac_demo
//
//  Created by 仝兴伟 on 2017/7/5.
//  Copyright © 2017年 仝兴伟. All rights reserved.
//

#import "MyImage.h"

@implementation MyImage

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
    // Drawing code here.
    
    [self setWantsLayer:YES];
    [[NSColor blackColor] setFill];
    
//    NSBezierPath.init(roundedRect: NSRect(x: 0, y: 0, width: 128, height: 50), xRadius: 25, yRadius: 25).fill()
    
    [[NSBezierPath init]drawBackgroundInRect:NSMakeRect(0, 0, 128, 50)];
    
    NSMutableAttributedString *acon = [[NSMutableAttributedString init]stringByAppendingString:self.ws];
    
    
    
    
}

@end
