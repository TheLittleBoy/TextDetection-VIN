//
//  VINDetectionViewController.m
//  TextDetection-VIN
//
//  Created by Mac on 2019/3/14.
//  Copyright © 2019 🚗. All rights reserved.
//

#import "VINDetectionViewController.h"
#import "Firebase.h"
#import <AVFoundation/AVFoundation.h>

@interface VINDetectionViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    UILabel *textLabel;
    AVCaptureDevice *device;
    NSString *recognizedText;
    BOOL isFocus;
    BOOL isInference;
    FIRVisionTextRecognizer *textRecognizer;
}
@property (nonatomic, assign) CGFloat m_width; //扫描框宽度
@property (nonatomic, assign) CGFloat m_higth; //扫描框高度
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *captureVideoDataOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@end

#define SCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define SCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)
#define m_scanViewY  150.0
#define m_scale [UIScreen mainScreen].scale

@implementation VINDetectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = @"扫一扫";
    self.view.backgroundColor = [UIColor blackColor];
    self.navigationController.navigationBar.translucent = NO;

    //给个默认值
    self.m_width = (SCREEN_WIDTH - 20);
    self.m_higth = 50.0;
    recognizedText = @"";
    
    //初始化识别器
    FIRVision *vision = [FIRVision vision];
    //这里仅仅使用离线识别功能。‼️如果要想使用在线识别，请到Firebase官网注册APP，并购买相关服务‼️
    textRecognizer = [vision onDeviceTextRecognizer];
    
    //初始化摄像头
    [self initAVCaptureSession];
}

- (void)initAVCaptureSession{
    
    self.session = [[AVCaptureSession alloc] init];
    NSError *error;
    
    device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (error) {
        NSLog(@"%@",error);
    }
    
    //输出流
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary
                                   dictionaryWithObject:value forKey:key];
    self.captureVideoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.captureVideoDataOutput setVideoSettings:videoSettings];
    
    dispatch_queue_t queue;
    queue = dispatch_queue_create("cameraQueue", NULL);
    [self.captureVideoDataOutput setSampleBufferDelegate:self queue:queue];
    
    if ([self.session canAddInput:self.videoInput]) {
        [self.session addInput:self.videoInput];
    }
    if ([self.session canAddOutput:self.captureVideoDataOutput]) {
        [self.session addOutput:self.captureVideoDataOutput];
    }
    
    //输出照片铺满屏幕
    if ([self.session canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        self.session.sessionPreset = AVCaptureSessionPresetHigh;
    }
    
    //初始化预览图层
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (orientation == UIInterfaceOrientationPortrait) {
        [[self.previewLayer connection] setVideoOrientation:AVCaptureVideoOrientationPortrait];
        
    }
    else if (orientation == UIInterfaceOrientationLandscapeLeft) {
        [[self.previewLayer connection] setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
    }
    else if (orientation == UIInterfaceOrientationLandscapeRight) {
        [[self.previewLayer connection] setVideoOrientation:AVCaptureVideoOrientationLandscapeRight];
    }
    else {
        [[self.previewLayer connection] setVideoOrientation:AVCaptureVideoOrientationPortraitUpsideDown];
    }
    
    self.previewLayer.frame = CGRectMake(0,0, SCREEN_WIDTH,SCREEN_HEIGHT);
    
    [self.previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
    self.view.layer.masksToBounds = YES;
    [self.view.layer addSublayer:self.previewLayer];
    
    //扫描框
    [self initScanView];
    
    //扫描结果label
    textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, (SCREEN_HEIGHT - 100)/2.0, SCREEN_WIDTH, 100)];
    textLabel.textAlignment = NSTextAlignmentCenter;
    textLabel.numberOfLines = 0;
    
    textLabel.font = [UIFont systemFontOfSize:19];
    
    textLabel.textColor = [UIColor whiteColor];
    [self.view addSubview:textLabel];
    
    //完成按钮
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:button];
    button.frame = CGRectMake((SCREEN_WIDTH - 100)/2.0, SCREEN_HEIGHT - 164, 100, 50);
    [button setTitle:@"完成" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(clickedFinishBtn:) forControlEvents:UIControlEventTouchUpInside];
    
    //对焦
    int flags =NSKeyValueObservingOptionNew;
    [device addObserver:self forKeyPath:@"adjustingFocus" options:flags context:nil];
}

- (void)initScanView
{
    // 中间空心洞的区域
    CGRect cutRect = CGRectMake((SCREEN_WIDTH - _m_width)/2.0,m_scanViewY, _m_width, _m_higth);
    
    UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(0,0, SCREEN_WIDTH,SCREEN_HEIGHT)];
    // 挖空心洞 显示区域
    UIBezierPath *cutRectPath = [UIBezierPath bezierPathWithRect:cutRect];
    
    //将circlePath添加到path上
    [path appendPath:cutRectPath];
    path.usesEvenOddFillRule = YES;
    
    CAShapeLayer *fillLayer = [CAShapeLayer layer];
    fillLayer.path = path.CGPath;
    fillLayer.fillRule = kCAFillRuleEvenOdd;
    fillLayer.opacity = 0.4;//透明度
    fillLayer.backgroundColor = [UIColor lightGrayColor].CGColor;
    [self.view.layer addSublayer:fillLayer];
    
    // 边界校准线
    const CGFloat lineWidth = 2;
    UIBezierPath *linePath = [UIBezierPath bezierPathWithRect:CGRectMake(cutRect.origin.x - lineWidth,
                                                                         cutRect.origin.y - lineWidth,
                                                                         cutRect.size.width / 4.0,
                                                                         lineWidth)];
    //追加路径
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cutRect.origin.x - lineWidth,
                                                                     cutRect.origin.y - lineWidth,
                                                                     lineWidth,
                                                                     cutRect.size.height / 4.0)]];
    
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cutRect.origin.x + cutRect.size.width - cutRect.size.width / 4.0 + lineWidth,
                                                                     cutRect.origin.y - lineWidth,
                                                                     cutRect.size.width / 4.0,
                                                                     lineWidth)]];
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cutRect.origin.x + cutRect.size.width ,
                                                                     cutRect.origin.y - lineWidth,
                                                                     lineWidth,
                                                                     cutRect.size.height / 4.0)]];
    
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cutRect.origin.x - lineWidth,
                                                                     cutRect.origin.y + cutRect.size.height - cutRect.size.height / 4.0 + lineWidth,
                                                                     lineWidth,
                                                                     cutRect.size.height / 4.0)]];
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cutRect.origin.x - lineWidth,
                                                                     cutRect.origin.y + cutRect.size.height,
                                                                     cutRect.size.width / 4.0,
                                                                     lineWidth)]];
    
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cutRect.origin.x + cutRect.size.width,
                                                                     cutRect.origin.y + cutRect.size.height - cutRect.size.height / 4.0 + lineWidth,
                                                                     lineWidth,
                                                                     cutRect.size.height / 4.0)]];
    [linePath appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(cutRect.origin.x + cutRect.size.width - cutRect.size.width / 4.0 + lineWidth,
                                                                     cutRect.origin.y + cutRect.size.height,
                                                                     cutRect.size.width / 4.0,
                                                                     lineWidth)]];
    
    CAShapeLayer *pathLayer = [CAShapeLayer layer];
    pathLayer.path = linePath.CGPath;// 从贝塞尔曲线获取到形状
    pathLayer.fillColor = [UIColor orangeColor].CGColor; // 闭环填充的颜色
    [self.view.layer addSublayer:pathLayer];
    
    UILabel *tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, m_scanViewY - 34, SCREEN_WIDTH, 25)];
    [self.view addSubview:tipLabel];
    tipLabel.text = @"请对准VIN码进行扫描";
    tipLabel.textAlignment = NSTextAlignmentCenter;
    tipLabel.textColor = [UIColor whiteColor];
}

-(void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if([keyPath isEqualToString:@"adjustingFocus"]){
        BOOL adjustingFocus =[[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1]];
        isFocus = adjustingFocus;
        NSLog(@"Is adjusting focus? %@", adjustingFocus ?@"YES":@"NO");
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    //
    if (!isFocus && !isInference) {
        isInference = YES;
        
        // Calculate the image orientation
        FIRVisionDetectorImageOrientation orientation;
        
        //指定使用后置摄像头
        AVCaptureDevicePosition devicePosition = AVCaptureDevicePositionBack;
        
        //校准图像方向
        UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
        switch (deviceOrientation) {
            case UIDeviceOrientationPortrait:
                if (devicePosition == AVCaptureDevicePositionFront) {
                    orientation = FIRVisionDetectorImageOrientationLeftTop;
                } else {
                    orientation = FIRVisionDetectorImageOrientationRightTop;
                }
                break;
            case UIDeviceOrientationLandscapeLeft:
                if (devicePosition == AVCaptureDevicePositionFront) {
                    orientation = FIRVisionDetectorImageOrientationBottomLeft;
                } else {
                    orientation = FIRVisionDetectorImageOrientationTopLeft;
                }
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                if (devicePosition == AVCaptureDevicePositionFront) {
                    orientation = FIRVisionDetectorImageOrientationRightBottom;
                } else {
                    orientation = FIRVisionDetectorImageOrientationLeftBottom;
                }
                break;
            case UIDeviceOrientationLandscapeRight:
                if (devicePosition == AVCaptureDevicePositionFront) {
                    orientation = FIRVisionDetectorImageOrientationTopRight;
                } else {
                    orientation = FIRVisionDetectorImageOrientationBottomRight;
                }
                break;
            default:
                orientation = FIRVisionDetectorImageOrientationTopLeft;
                break;
        }
        
        FIRVisionImageMetadata *metadata = [[FIRVisionImageMetadata alloc] init];
        metadata.orientation = orientation;
        
        //这里不仅可以使用buffer初始化，也可以使用 image 进行初始化
        FIRVisionImage *image = [[FIRVisionImage alloc] initWithBuffer:sampleBuffer];
        image.metadata = metadata;
        
        //开始识别
        [textRecognizer processImage:image
                          completion:^(FIRVisionText *_Nullable result,
                                       NSError *_Nullable error) {
                              if (error == nil && result != nil) {
                                  //识别结果会包很多层：FIRVisionText——>FIRVisionTextBlock->FIRVisionTextLine->FIRVisionTextElement
                                  for (FIRVisionTextBlock *block in result.blocks) {
                                      for (FIRVisionTextLine *line in block.lines) {
                                          for (FIRVisionTextElement *element in line.elements) {
                                              NSString *elementText = element.text;
                                              //识别17位的VIN码
                                              if (elementText.length == 17) {
                                                  //正则表达式，排除特殊字符
                                                  NSString *regex = @"[ABCDEFGHJKLMNPRSTUVWXYZ1234567890]{17}";
                                                  NSPredicate *test = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
                                                  //识别成功
                                                  if ([test evaluateWithObject:elementText]) {
                                                      
                                                      //停止扫描
                                                      [self.session stopRunning];
                                                      
                                                      //播放音效
                                                      NSURL *url=[[NSBundle mainBundle]URLForResource:@"scanSuccess.wav" withExtension:nil];
                                                      SystemSoundID soundID=8787;
                                                      AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &soundID);
                                                      AudioServicesPlaySystemSound(soundID);
                                                      
                                                      //在屏幕上输入结果
                                                      self->recognizedText = elementText;
                                                      self->textLabel.text = self->recognizedText;
                                                      
                                                      NSLog(@"%@",self->recognizedText);
                                                      return;
                                                  }
                                              }
                                          }
                                      }
                                  }
                              }
                              //继续识别
                              self->isInference = NO;
                          }];
    }
}

- (void)viewWillAppear:(BOOL)animated{
    
    [super viewWillAppear:YES];
    
    if (self.session) {
        [self.session startRunning];
    }
}

- (void)viewDidDisappear:(BOOL)animated{
    
    [super viewDidDisappear:YES];
    
    if (self.session) {
        [self.session stopRunning];
    }
    
    [device removeObserver:self forKeyPath:@"adjustingFocus" context:nil];
}

/**
 完成按钮点击事件

 @param sender 按钮
 */
- (void)clickedFinishBtn:(UIButton *)sender {
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(recognitionComplete:)]) {
        [self.delegate recognitionComplete:textLabel.text];
    }
    
    [self.navigationController popViewControllerAnimated:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
