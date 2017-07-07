//
//  SocketManger.h
//  Scoket_Demo
//
//  Created by 仝兴伟 on 2017/5/31.
//  Copyright © 2017年 仝兴伟. All rights reserved.
//   socket 从 127.0.0.1 获取流量包，并且转发到proxy服务器

#import <Foundation/Foundation.h>
@class DataForwordModel,RiskModel;
@interface SocketManger : NSObject

+ (instancetype)sharedSocketManger;

@property (nonatomic, readonly) int socksProxyPort;

@property (nonatomic, strong)DataForwordModel *dataSocket;
@property (nonatomic, strong) RiskModel *riskModel;
// 开始
- (void)startListen;
// 结束
- (void)stopListen;
@end
