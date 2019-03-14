//
//  VINDetectionViewController.h
//  TextDetection-VIN
//
//  Created by Mac on 2019/3/14.
//  Copyright © 2019 🚗. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol VINDetectionViewControllerDelegate <NSObject>

/**
 识别成功之后，点击完成按钮的回调

 @param result VIN码
 */
- (void)recognitionComplete:(NSString *)result;

@end

/**
 VIN 识别
 */
@interface VINDetectionViewController : UIViewController

@property(nonatomic, weak) id<VINDetectionViewControllerDelegate> delegate;

@end
