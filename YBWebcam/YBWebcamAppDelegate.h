//
//  YBWebcamAppDelegate.h
//  YBWebcam
//
//  Created by Allen Yee on 3/30/13.
//  Copyright (c) 2013 Allen Yee. All rights reserved.
//

#import <UIKit/UIKit.h>

@class YBWebcamViewController;

@interface YBWebcamAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UINavigationController *nc;
@property (strong, nonatomic) YBWebcamViewController *viewController;

@end
