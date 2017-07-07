//
//  SocketManger.m
//  Scoket_Demo
//
//  Created by 仝兴伟 on 2017/5/31.
//  Copyright © 2017年 仝兴伟. All rights reserved.
//  109730

#import "SocketManger.h"
#include <string.h>
#include <pthread.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>

//#import "DataForwordModel.h"
//#import "RiskModel.h"
#pragma mark --  http header携带的标识结构体
struct client_data {
    uint8_t magic[4];           //'C'  'S'  'T'  'M'    cloudscreen terminal 的意思
    uint16_t length;            //扩展部分的长度 现在没有扩展长度为0
    uint8_t version;            //版本号
    uint8_t reserve;            //保留
    uint32_t dataHigh;
    uint32_t datalow;
};

#pragma mark --

int g_fd; // 本地端口 socket 句柄

int g_chclientfd = 0;

struct client_data msg; // 标识信息结构体

@interface SocketManger ()
@property (nonatomic, assign) long long  socketToken; // HTTP header 添加的字段

@property (nonatomic, assign) UInt32 hight;
@property (nonatomic, assign) UInt32 low;
@end

@implementation SocketManger
+(instancetype)sharedSocketManger {
    static SocketManger *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc]init];
    });
    return instance;
}

#pragma mark -- 

-(void)setDataSocket:(DataForwordModel *)dataSocket{
    _dataSocket = dataSocket;
}

-(void)setRiskModel:(RiskModel *)riskModel{
    _riskModel = riskModel;
}
- (void)startListen {
    
    self.socketToken = 5730;
    self.hight = (UInt32)(self.socketToken>> 32);
    self.low =  (UInt32)self.socketToken;
    NSLog(@"%d --socket-- %d", self.hight, self.low);

    // 初始化标识
    [self initIdentifierMessage];
    
    // 初始化socket
    [self socket_init];
}


#pragma mark -- 初始化soxket
// socket 初始化
- (void)socket_init {
    int iret = 0 ; //
    int on =1; //
    
    struct sockaddr_in stLocal;
    socklen_t socklen = sizeof(stLocal);
    
    g_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (g_fd <= 0 ) {
        printf("local socket create error! errno=%d\n",errno);
        
        
    } else {
        printf("local socket create ok!fd=%d\n", g_fd);
    }
    
    setsockopt(g_fd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on));
    
    setsockopt(g_fd, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
    
    stLocal.sin_family = AF_INET;
    
    stLocal.sin_addr.s_addr = inet_addr("127.0.0.1");
    
    stLocal.sin_port = htons(9527);
    
    iret = bind(g_fd, (struct sockaddr *)&stLocal , socklen);
    if (iret != 0) {
        printf("local socket bind error!iret = %d, errno = %d\n",iret, errno);

    } else {
        printf("local socket bind ok!\n");
    }
    
    iret = listen(g_fd, 50);
    if (iret != 0) {
        printf("local socket listen error! iret = %d, errno = %d\n",iret, errno);
    }
    
    NSThread *threadtest = [[NSThread alloc]initWithTarget:self selector:@selector(sockaccept) object:@"nspthreadtest"];
    //启动线程
    [threadtest start];
    
    _socksProxyPort = sock_port(g_fd);
}

#pragma mark -- 线程方法 sockaccept
- (void)sockaccept {
    int clientfd = 0;
    struct sockaddr_in stclient ;
    socklen_t socklen = sizeof(stclient);
    
    printf("waiting for accept client socket...\n");
    while(1)
    {
        clientfd = accept(g_fd, (struct sockaddr *)&stclient, &socklen);
        if (clientfd < 0 ) {
            printf("accept error, errno = %d!\n", errno);
            [self stopListen];
            [NSThread exit];
            return;
        } else {
            printf("accept a new client socket addr = \n%s:%d, clientfd = %d\n", inet_ntoa(stclient.sin_addr), ntohs(stclient.sin_port), clientfd);
            
            //和真正的代理，建立一个TCP的链接
            
            //            NSThread * forwardThread = [[NSThread alloc]initWithTarget:self selector:@selector(sockrecvlocal:) object: [NSNumber numberWithInt:localfd]];
            
            // 反向代理
            NSThread * reverseProxyThread = [[NSThread alloc]initWithTarget:self selector:@selector(reverseProxySockRecvClientfd:) object: [NSNumber numberWithInt: clientfd]];
            //启动线程
            [reverseProxyThread start];
        }
    }
}

#pragma mark -- 反向代理
// 接收到本地发出的http请求  反向代理模式处理
- (void)reverseProxySockRecvClientfd: (NSNumber *) clientfd {
    int newclientfd = clientfd.intValue;
    char acbuf[16384] = {0};
    int iret = 0;
    int isend = 0;
    int ileft = 0;
    int serverfd = 0;
    int on = 1;
    BOOL isFisrtReceive = YES; // 用来判断 http还是 https
    BOOL isHttps = NO; // 判断 http 标识
    
    setsockopt(newclientfd, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
    
    printf("client socket recieve local connect ,clientfd = %d\n", newclientfd);
    while (1) {
        if (isFisrtReceive) {
            isFisrtReceive = NO;
            if ([self firstReceiveLocalProxy: newclientfd serverfd: &serverfd isHttps: &isHttps] < 0) {
                printf("client socket recieved error = %d, close clientfd = %d, serverfd = %d, errno = %d\n", iret, newclientfd, serverfd, errno);
                close(newclientfd);
                close(serverfd);
                [NSThread exit];
                return;
            }
        } else {
            /*
             //不加头
             memset(acbuf, 0,16384);
             iret = (int)recv(newlocalfd, acbuf , 16384, 0);
             if (iret <= 0) {
             printf("local socket recv error=%d, close localfd=%d, clientfd=%d\n", iret, newlocalfd, clientfd);
             close(newlocalfd);
             close(clientfd);
             [NSThread exit];
             return;
             } else {
             ileft = iret;
             isend = proxyclientsend(clientfd, acbuf, ileft);
             if (0 > isend) {
             printf("client socket send error=%d,close localfd=%d, clientfd=%d\n", isend, newlocalfd, clientfd);
             close(newlocalfd);
             close(clientfd);
             [NSThread exit];
             return;
             } else {
             ileft -= isend;
             if (ileft == 0) {
             printf("send charles ok!ileft=%d, clientfd=%d, isend=%d\n", ileft, clientfd, isend);
             }
             }
             }*/
            memset(acbuf, 0,16384);
#pragma mark --------------------------------------
            iret = (int)recv(newclientfd, acbuf , 16384, 0);
            
//            if (isHttps) {
//                iret = (int)recv(newclientfd, acbuf , 16384, 0);
//            } else {
//                // 加头
//                iret = (int)recv(newclientfd, acbuf + sizeof(struct client_data), 16384 - sizeof(struct client_data), 0);
//            }
            
            if (iret <= 0) {
                printf("client socket recieve error = %d, close clientfd = %d, close serverfd = %d, errno = %d\n", iret, newclientfd, serverfd, errno);
                close(newclientfd);
                close(serverfd);
                [NSThread exit];
                return;
            } else {
                ileft = iret;
                
                // 本地发送给 proxy server
                isend = proxyclientsend(serverfd, acbuf, ileft);
//                if (isHttps) {
//                    ileft = iret;
//                    
//                    // 本地发送给 proxy server
//                    isend = proxyclientsend(serverfd, acbuf, ileft);
//                } else {
//                    memcpy(acbuf, &msg, 16);
//                    ileft = iret;
//                    isend = proxyclientsend(serverfd, acbuf, ileft + sizeof(struct client_data));
//                }
                
                if (0 > isend) {
                    printf("client socket send data to server socket error = %d,close clientfd = %d, serverfd = %d\n", isend, newclientfd, serverfd);
                    close(newclientfd);
                    close(serverfd);
                    [NSThread exit];
                    return;
                } else {
                    ileft -= isend;
                    if (ileft == 0) {
                        printf("client socket send data to server ok!ileft = %d, clientfd = %d, serverfd = %d, isend = %d\n", ileft, newclientfd, serverfd, isend);
                    }
                }
            }
        }
    }
}



#pragma mark -- 本地发送以及接收服务器数据
int proxyclientsend(int sockfd, char *pcbuf, int len) {
    int iret  =0;
    int ileft =0;
    int icount = 0;
    
    if (NULL == pcbuf) {
        return -1;
    }
    
    ileft = len;
    while(1)
    {
        iret = (int)send(sockfd, pcbuf, ileft, 0 );
        
        printf("will send data [buf]::\n%s, iret=%d, len=%d\n", pcbuf, iret, len);
        
        if (0 >= iret && errno != 0) {
            
            printf(" socket send data error!iret= %d, socketfd = %d, errno = %d\n", iret, sockfd, errno);
            if (-35 == iret) {
                continue;
            }
            close(sockfd);
            [NSThread exit];
            
            return -1;
        } else {
            icount++;
#pragma mark ??????
            if (icount > 10) {
                break;
            }
            ileft -= iret;
            printf("socket send data successful! iret= %d, ileft=%d, socketfd = %d\n", iret, ileft, sockfd);
            if (ileft == 0) {
                printf("left is zero!\n");
                break;
            }
        }
    }
    
    return iret;
}


#pragma mark -- firstReceiveLocalProxy
- (int)firstReceiveLocalProxy: (int) clientfd serverfd: (int *)serverfd isHttps: (BOOL *) isHttps {
    char acbuf[16384] = {0};
    int newserverfd = 0;
    int isend = 0;
    int ileft = 0;
    int iret = 0;
    int iretConnect = 0;
    BOOL newIsHttps = NO;
    
    memset(acbuf, 0,16384);
    
    iret = (int)recv(clientfd, acbuf + sizeof(struct client_data), 16384 - sizeof(struct client_data), 0);
    if (iret <= 0) {
        printf("client socket recieve error = %d, close clientfd = %d, serverfd = %d, errno = %d\n", iret, clientfd, newserverfd, errno);
        if (newserverfd) {
            shutdown(newserverfd, 2);
            close(newserverfd);
        }
        close(clientfd);
        [NSThread exit];
        return -1;
    } else {
        printf("client socket recieve [buf]::\n%s, iret = %d\n",acbuf + 16, iret);
        
        if (strstr(acbuf + sizeof(struct client_data), "CONNECT")) {
            newIsHttps = YES;
            *isHttps = newIsHttps;
        } else {
            newIsHttps = NO;
            *isHttps = newIsHttps;
        }
        
        // 反向代理  客户端 连向 proxy
        iretConnect = [self reverseProxyClientToServerInit: clientfd newfd: &newserverfd isHttps: newIsHttps];
        
        // 判断是否链接成功
        if (0 != iretConnect) {
            printf("client to server connect error, close clientfd = %d, close serverfd = %d\n", clientfd, newserverfd);
            close(clientfd);
            //            close(newserverfd);
            [NSThread exit];
            return -1;
        } else {
            if (newIsHttps) {
                // 反向正向区别
                char * establishBuf = "HTTP/1.1 200 Connection established\r\n\r\n";
                // 自己回一个 established
                isend = proxyclientsend(clientfd, establishBuf, (int)strlen(establishBuf));
                if (0 > isend) {
                    printf("socket send data to client error = %d, close clientfd = %d, serverfd = %d\n", isend, clientfd, newserverfd);
                    close(clientfd);
                    close(newserverfd);
                    [NSThread exit];
                    return -1;
                } else {
                    *serverfd = newserverfd;
                    return 1;
                }
            }
        }
        
        ileft = iret;
        
        memcpy(acbuf, &msg, 16);
        
        // 发送 acbuf
        isend = proxyclientsend(newserverfd, acbuf, ileft + sizeof(struct client_data));
        
        if (0 > isend) {
            printf("socket send data to server error = %d,close clientfd = %d, serverfd = %d\n", isend, clientfd, newserverfd);
            close(clientfd);
            close(newserverfd);
            [NSThread exit];
            return -1;
        } else {
            ileft -= isend;
            if (ileft == 0) {
                printf("send data to server ok! ileft = %d, clientfd = %d, serverfd = %d, isend = %d\n", ileft, clientfd, newserverfd, isend);
            }
        }
        *serverfd = newserverfd;
        return 1;
    }
}

#pragma mark -- reverseProxyClientToServerInit 链接proxy服务器
- (int)reverseProxyClientToServerInit: (int)clientfd newfd: (int *) newserverfd isHttps: (BOOL) isHttps {
    int iret = 0 ;
    int isend = 0;
    
    struct sockaddr_in stClient;
    socklen_t  socklen = sizeof(stClient);
    int serverfd = 0;
    NSDictionary * dicarrinfo  = [[NSDictionary alloc] init];
    
    
    serverfd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (serverfd <= 0 ) {
        printf("server socket create error! errno\n", errno);
        return -1;
    } else {
        printf("server socket create ok! serverfd=%d, clientfd = %d\n", serverfd,  clientfd);
    }
    
    int on = 1;
    
    setsockopt(serverfd, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
    
    NSString * proxyHost;
    if (isHttps) {
        proxyHost = @"10.10.11.42";//@"10.10.11.43";//@"10.10.10.10";
    } else {
        proxyHost = @"10.10.11.42";//@"10.10.11.43";//@"10.10.10.10";
    }
    const char *resultCString = NULL;
    if ([proxyHost canBeConvertedToEncoding:NSUTF8StringEncoding]) {
        resultCString = [proxyHost cStringUsingEncoding:NSUTF8StringEncoding];
    }
    
    stClient.sin_family = AF_INET;
    if (isHttps) {
        stClient.sin_addr.s_addr = inet_addr(resultCString);
        
        stClient.sin_port = htons(443);
    } else {
        stClient.sin_addr.s_addr = inet_addr(resultCString);
        
        stClient.sin_port = htons(80);
    }
    
    iret = connect(serverfd, (struct sockaddr *)&stClient, socklen);
    
    if (0 != iret) {
        printf("server socket connect to server error! iret = %d, errno = %d\n", iret, errno);
        //        close(serverfd);
        close(clientfd);
        [NSThread exit];
        return -1;
    } else {
        *newserverfd = serverfd;
        printf("server socket connect to server ok! serverfd = %d, clientfd = %d\n", serverfd, clientfd);
        
        if (isHttps) {
            char acbuf[16384] = {0};
            memcpy(acbuf, &msg, sizeof(struct client_data));
            isend = proxyclientsend(serverfd, acbuf, sizeof(struct client_data));
        }
    }
    
    dicarrinfo= @{@"client": [NSNumber numberWithInt:clientfd], @"server": [NSNumber numberWithInt: serverfd]};
    
    NSThread * recvServerDataThread = [[NSThread alloc]initWithTarget:self selector: @selector(proxyclient2server_recv:) object: dicarrinfo];
    //启动线程
    [recvServerDataThread start];
    
    return 0;
}

#pragma mark -- proxyclient2server_recv
// 客户端接受到服务器返回的数据
- (void)proxyclient2server_recv: (NSDictionary *)arrayinfo {
    int iret  = 0;
    char acbuf[16384]={0};
    int clientfd = 0;
    int serverfd = 0;
    int ileft = 0;
    int isend = 0;
    NSNumber * clientNum = arrayinfo[@"client"];
    NSNumber * serverNum = arrayinfo[@"server"];
    
    clientfd = clientNum.intValue;
    serverfd = serverNum.intValue;
    
    printf("client recieved server send data, clientfd = %d, serverfd = %d\n", clientfd, serverfd);
    
    while (1) {
        
        memset(acbuf, 0 , 16384);
        
        iret = (int)recv(serverfd, acbuf, 16384,0);
        if (0 >= iret) {
            printf("recieve data from sever error! iret = %d,errno = %d, serverfd = %d\n", iret, errno,  serverfd);
            if (0 == iret) {
                printf("server close connect! serverfd = %d\n", serverfd);
            }
            close(clientfd);
            close(serverfd);
            [NSThread exit];
            return;
        } else {
            printf("recieved data from sever buf=\n%s, len=%d\n", acbuf, iret);
            ileft = iret;
            while(1) {
                isend = proxyclientsend(clientfd, acbuf, ileft);
                if (0 > isend) {
                    printf("send data to client socket error=%d, clientfd=%d, serverfd = %d, errno = %d\n", isend, clientfd, serverfd, errno);
                    close(serverfd);
                    close(clientfd);
                    [NSThread exit];
                    return;
                } else {
                    ileft -= isend;
                    if (ileft == 0) {
                        printf("send data to client socket ok! ileft = %d\n", ileft);
                        break;
                    }
                }
            }
        }
    }
}


#pragma mark -- 停止socket 
- (void)stopListen {
    NSLog(@"-----close g_fd = %d", g_fd);
    close(g_fd);
    g_fd = 0;
}

#pragma mark -- 获取系统随机端口号
//  获取系统随机端口号
int sock_port (int fd) {
    struct sockaddr_in sin;
    socklen_t len = sizeof(sin);
    if (getsockname(fd, (struct sockaddr *)&sin, &len) < 0) {
        NSLog(@"getsock_port(%d) error: %s",
              fd, strerror (errno));
        return 0;
    }else{
        return ntohs(sin.sin_port);
    }
}



#pragma mark -- 初始化结构体
- (void)initIdentifierMessage {
    memset(&msg, 0, sizeof(struct client_data));
    msg.magic[0]='C';
    msg.magic[1]='S';
    msg.magic[2]='T';
    msg.magic[3]='M';
    
    msg.length = 0;
    msg.version = 1;
    msg.reserve = 0;
    

    msg.dataHigh = HTONL(self.hight);
    msg.datalow = HTONL(self.low);
}


@end





