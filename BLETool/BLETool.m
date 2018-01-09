//
//  BLETool.m
//  BlueToothData
//
//  Created by apple on 16/11/25.
//  Copyright © 2016年 孙晓东. All rights reserved.
//

#import "BLETool.h"
#import <CoreBluetooth/CoreBluetooth.h>

typedef void(^sendState)(SENDDATASTATE sendState);

@interface BlueToothHelp()<CBCentralManagerDelegate,CBPeripheralDelegate>
@property (nonatomic,copy)sendState sendState;
@property (nonatomic,copy)NSString *blueName;
@property (nonatomic,copy)ReadData readCharacterValue;
@property (nonatomic, strong)CBCentralManager *centralManager;//中心
@property (nonatomic,strong)CBPeripheral *peripheral;//外设
@property (nonatomic)dispatch_source_t timer;
@property (nonatomic)int timeout;
@property (nonatomic)int reConnectCount;
@property (nonatomic)float reConnectTime;
@property (nonatomic,assign)BOOL isOpen;
@property (nonatomic)int innerConnectCount;

@property (nonatomic,copy)NSString *service;
@property (nonatomic,copy)NSString *readCharacter;
@property (nonatomic,copy)NSString *writeCharacter;
@property (nonatomic,strong)NSData *sendData;
@end

@implementation BlueToothHelp
+ (BlueToothHelp *)shareInstance {
    static BlueToothHelp *help = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        help = [[self alloc] init];
    });
    return help;
}

- (instancetype)init {
    if (self = [super init]) {
        self.centralManager = [[CBCentralManager alloc]initWithDelegate:self queue:nil options:@{CBCentralManagerOptionShowPowerAlertKey:@NO}];
        self.isOpen = NO;
    }
    return self;
}
- (void)BlueToothBeginSendDataWithBTName:(NSString *)BTName
                                 maxTime:(int)maxTime    //扫描时间
                                services:(NSString *)services
                      readCharacteristic:(NSString *)readCharacteristic
                     writeCharacteristic:(NSString *)writeCharacteristic
                          reConnectCount:(int)reConnectCount  //失败重连次数
                        reConnectMaxTime:(float)reConnectMaxTime  //重连次数时间间隔
                                sendData:(NSData *)sendData
                             returnState:(void(^)(SENDDATASTATE state))dataState
                                readData:(ReadData)readData {
    
    if (maxTime <= 0) {
        return;
    }
    self.innerConnectCount = 0;
    self.reConnectCount = reConnectCount;
    self.reConnectTime = reConnectMaxTime;
    self.timeout = maxTime;
    self.readCharacterValue = readData;
    self.service = services;
    self.writeCharacter = writeCharacteristic;
    self.readCharacter = readCharacteristic;
    self.sendData = sendData;
    [self timeCountDown];
    [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    self.blueName = BTName;
    self.sendState = dataState;
}


- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central == self.centralManager) {
        switch (central.state) {
            case CBManagerStatePoweredOn:
                self.blueToothState = BlueToothOpen;
                break;
            default:
                self.blueToothState = BlueToothClose;
                break;
        }
    }
}
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if ([advertisementData[@"kCBAdvDataLocalName"] isEqualToString:self.blueName]) {
        [central stopScan];
        [central connectPeripheral:peripheral options:nil];
        self.peripheral = peripheral;
    }
    
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    if (central == self.centralManager) {
        peripheral.delegate = self;
        [peripheral discoverServices:@[[CBUUID UUIDWithString:self.service]]];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (self.sendState) {
        self.sendState(SendDataFailure);
    }
}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    _timeout = 0;
    dispatch_source_cancel(_timer);
    for (CBService *service in peripheral.services) {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:self.service]]) {
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:self.readCharacter]]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:self.writeCharacter]]) {
            
            [peripheral writeValue:self.sendData forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (self.sendState) {
        [self.centralManager cancelPeripheralConnection:peripheral];
        self.sendState(SendDataSuccess);
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
    if (self.readCharacterValue) {
        self.readCharacterValue(characteristic.value);
    }
}
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    if (_timeout >= 0) {
        self.innerConnectCount ++;
        if (self.innerConnectCount >= self.reConnectCount) {
            if (self.sendState) {
                self.sendState(ReConnectCountEnd);
            }
            return;
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.reConnectTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.centralManager connectPeripheral:peripheral options:nil];
        });
    }
}
//字符串转化为16进制
- (NSData *)convertHexStrToData:(NSString *)str {
    if (!str || [str length] == 0) {
        return nil;
    }
    NSMutableData *hexData = [[NSMutableData alloc] initWithCapacity:8];
    NSRange range;
    if ([str length] % 2 == 0) {
        range = NSMakeRange(0, 2);
    } else {
        range = NSMakeRange(0, 1);
    }
    for (NSInteger i = range.location; i < [str length]; i += 2) {
        unsigned int anInt;
        NSString *hexCharStr = [str substringWithRange:range];
        NSScanner *scanner = [[NSScanner alloc] initWithString:hexCharStr];
        
        [scanner scanHexInt:&anInt];
        NSData *entity = [[NSData alloc] initWithBytes:&anInt length:1];
        [hexData appendData:entity];
        
        range.location += range.length;
        range.length = 2;
    }
    return hexData;
}
//nsdata转化为字符串
- (NSString *)convertDataToHexStr:(NSData *)data {
    if (!data || [data length] == 0) {
        return @"";
    }
    NSMutableString *string = [[NSMutableString alloc] initWithCapacity:[data length]];
    
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        unsigned char *dataBytes = (unsigned char*)bytes;
        for (NSInteger i = 0; i < byteRange.length; i++) {
            NSString *hexStr = [NSString stringWithFormat:@"%x", (dataBytes[i]) & 0xff];
            if ([hexStr length] == 2) {
                [string appendString:hexStr];
            } else {
                [string appendFormat:@"0%@", hexStr];
            }
        }
    }];
    return string;
}




@end

