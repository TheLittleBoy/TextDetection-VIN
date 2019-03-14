//
//  ViewController.m
//  TextDetection-VIN
//
//  Created by Mac on 2019/3/14.
//  Copyright © 2019 🚗. All rights reserved.
//

#import "ViewController.h"
#import "VINDetectionViewController.h"

@interface ViewController ()<VINDetectionViewControllerDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.title = @"🚗";
}

- (IBAction)startButtonAction:(id)sender {
    
    VINDetectionViewController *vinVC = [[VINDetectionViewController alloc] init];
    vinVC.delegate = self;
    [self.navigationController pushViewController:vinVC animated:YES];
}

/**
 识别成功之后，点击完成按钮的回调
 
 @param result VIN码
 */
- (void)recognitionComplete:(NSString *)result {
    
    NSLog(@"%@",result);
}

@end
