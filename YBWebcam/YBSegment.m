//
//  YBSegment.m
//  YBT_Webcam
//
//  Created by Allen Yee on 3/5/13.
//  Copyright (c) 2013 Yeesterbunny Tech. All rights reserved.
//

#import "YBSegment.h"
#import "YBConstants.h"

@implementation YBSegment

-(id)initWithData:(NSData*)data{
    self = [super init];
    if(self){
        self.segmentData = [[NSMutableData alloc]initWithData:data];
        [self createImageSegment];
    }
    return self;
}

-(void)createImageSegment{
    self.ybHeader = (YBHeader*)[self.segmentData bytes];
    self.imageData = [self.segmentData subdataWithRange:NSMakeRange(YBHeader_Length, self.ybHeader->imageDataLength)];
}

-(int)ybSegmentLength{
    return YBHeader_Length + [self.imageData length];
}

@end
