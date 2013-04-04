//
//  YBSegment.h
//  YBT_Webcam
//
//  Created by Allen Yee on 3/5/13.
//  Copyright (c) 2013 Yeesterbunny Tech. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YBConstants.h"

@interface YBSegment : NSObject
@property(nonatomic,strong)NSMutableData *segmentData;
@property(nonatomic,assign)YBHeader *ybHeader;
@property(nonatomic,strong)NSData *imageData;

-(id)initWithData:(NSData*)data;
-(int)ybSegmentLength;

@end
