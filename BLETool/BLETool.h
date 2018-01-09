//
//  BLETool.h
//  BlueToothData
//
//  Created by apple on 16/11/25.
//  Copyright © 2016年 孙晓东. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM (NSInteger,BTSTATE) {
    BlueToothOpen,
    BlueToothClose
};
typedef NS_ENUM(NSInteger,SENDDATASTATE){
    SendDataSuccess,
    SendDataFailure,
    SendDataTimeOut,
    ReConnectCountEnd
};
typedef void(^ReadData)(NSData *readData);
@interface BLETool: NSObject
//蓝牙是否打开
@property (nonatomic,assign)BTSTATE blueToothState;
//创建单例对象
+ (BLETool *)shareInstance;
//发送数据
- (void)BlueToothBeginSendDataWithBTName:(NSString *)BTName
                                 maxTime:(int)maxTime    //扫描时间
                                services:(NSString *)services
                      readCharacteristic:(NSString *)readCharacteristic
                     writeCharacteristic:(NSString *)writeCharacteristic
                          reConnectCount:(int)reConnectCount  //失败重连次数
                        reConnectMaxTime:(float)reConnectMaxTime  //重连次数时间间隔
                                sendData:(NSData *)sendData
                             returnState:(void(^)(SENDDATASTATE state))dataState
                                readData:(ReadData)readData;

- (NSString *)convertDataToHexStr:(NSData *)data;//nsdata转化为字符串
- (NSData *)convertHexStrToData:(NSString *)str;//字符串转化为16进制

@end

