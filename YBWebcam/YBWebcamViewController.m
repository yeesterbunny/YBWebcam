//
//  YBWebcamViewController.m
//  YBWebcam
//
//  Created by Allen Yee on 3/30/13.
//  Copyright (c) 2013 Allen Yee. All rights reserved.
//

#import "YBWebcamViewController.h"
#import "YBConstants.h"
#import "YBSegment.h"
#import "TCPServer.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>

@interface YBWebcamViewController () <UITableViewDelegate, UITableViewDataSource, TCPServerDelegate, NSNetServiceDelegate, NSNetServiceBrowserDelegate, NSStreamDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>{
    
    NSUInteger _readDataBufferPosition; // pointer position to show where I am in the data buffer
    BOOL manualWrite;
    BOOL _isStalker;
}

@property(nonatomic, strong)IBOutlet UITableView *tableView;
@property(nonatomic, strong)IBOutlet UIActivityIndicatorView *activityIndicator;
@property(nonatomic, strong)IBOutlet UIView *cameraView;
@property(nonatomic, strong)UIImageView *videoImageView;
@property(nonatomic, strong)NSMutableArray *services;
@property(nonatomic, strong)NSNetServiceBrowser *serviceBrowser;
@property(nonatomic, assign)BOOL searching;
@property(nonatomic, strong)TCPServer *server;
@property(nonatomic, strong)NSInputStream *inStream;
@property(nonatomic, strong)NSOutputStream *outStream;
@property(nonatomic,strong)NSMutableData *writeDataBuffer;
@property(nonatomic,strong)NSMutableData *readDataBuffer;

//AV Capture
@property(nonatomic,strong)AVCaptureSession *captureSession;
@property(nonatomic,strong)AVCaptureStillImageOutput *stillImageOutput;
@property(nonatomic,strong)AVCaptureVideoDataOutput *videoDataOutput;
@property(nonatomic,strong)AVCaptureDeviceInput *captureInput;
@end

@implementation YBWebcamViewController

-(id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if(self){
        [[UINavigationBar appearance] setTintColor:[UIColor greenColor]];
        UINavigationItem *item = [self navigationItem];
        [item setTitle:@"YBWebcam"];
        
        self.services = [[NSMutableArray alloc]init];
        self.serviceBrowser = [[NSNetServiceBrowser alloc]init];
        [self.serviceBrowser setDelegate:self];
        [self.serviceBrowser searchForServicesOfType:[TCPServer bonjourTypeFromIdentifier:SERVICE_NAME] inDomain:@"local"];
        _searching = NO;
        _isStalker = NO;
    }
    return self;
}


- (void)viewDidLoad
{ 
    [super viewDidLoad];
    
    _readDataBufferPosition = 0;

    [self setup];
    
    self.videoImageView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, self.cameraView.bounds.size.width, self.view.bounds.size.height)];
    [self.cameraView addSubview:self.videoImageView];
}

-(void)initCapture{
    NSError *error = nil;
    
    //Setup input
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] error:&error];
    
    if(error){
        NSLog(@"init capture ERROR: %@", [error description]);
    }
    
    self.captureInput = deviceInput;
    
    //Setup output
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc]init];
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    [captureOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    NSString *key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber *value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    
    AVCaptureStillImageOutput *imageOutput = [[AVCaptureStillImageOutput alloc]init];
    NSDictionary *outputSettings = [NSDictionary dictionaryWithObject:AVVideoCodecJPEG forKey:AVVideoCodecKey];
    [imageOutput setOutputSettings:outputSettings];
    
    //Create capture session
    self.captureSession = [[AVCaptureSession alloc]init];
    [self.captureSession addInput:self.captureInput];
    [self.captureSession addOutput:captureOutput];
    [self.captureSession addOutput:imageOutput];
    [self.captureSession setSessionPreset:AVCaptureSessionPresetMedium];
    [self.captureSession startRunning];
    
    self.videoDataOutput = captureOutput;
    self.stillImageOutput = imageOutput;
}

-(void)setup{
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(closeSessions) name:CAMERAVIEWDIDCLOSE object:nil];
    [self initCapture];
    if(self.server){
        self.server = nil;
        self.server.delegate = nil;
    }
    
    [self.inStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    self.inStream = nil;
    
    [self.outStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    self.outStream = nil;
    
    NSError *error = nil;
    self.server = [[TCPServer alloc]init];
    self.server.delegate = self;
    if(self.server == nil || ![self.server start:&error]){
        if(self.server == nil){
            NSLog(@"Failed creating server: server is nil");
        }
        else{
            NSLog(@"Failed creating server - errorCode: %@", [error description]);
        }
        return;
    }
    
    if(![self.server enableBonjourWithDomain:@"local" applicationProtocol:[TCPServer bonjourTypeFromIdentifier:SERVICE_NAME] name:nil]){
        NSLog(@"Failed publishing server");
        return;
    }
}

-(void)openStreams{
    self.inStream.delegate = self;
    [self.inStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self.inStream open];
    
    self.outStream.delegate = self;
    [self.outStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self.outStream open];
}

-(void)closeStreams{
    NSLog(@"Closing session");

    
    self.inStream.delegate = nil;
    [self.inStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self.inStream close];
    
    self.outStream.delegate = self;
    [self.outStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    [self.outStream close];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)updateUI{
    if(_searching){
        [_activityIndicator startAnimating];
    }
    else{
        [_activityIndicator stopAnimating];
        [self.tableView reloadData];
    }
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    _isStalker = YES;
    NSNetService *currentResolve = [self.services objectAtIndex:indexPath.row];
    [currentResolve setDelegate:self];
    [currentResolve resolveWithTimeout:0.0];
}

-(NSIndexPath*)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    if([self.services count] == 0){
        return nil;
    }
    
    return indexPath;
}

#pragma mark - UITableViewDataSource


-(UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *tableCellIdentifier = @"UITableViewCell";
	UITableViewCell *cell = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:tableCellIdentifier];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableCellIdentifier];
	}
    
    NSUInteger count = [self.services count];
    if(count > 0){
        NSNetService *netService = [self.services objectAtIndex:indexPath.row];
        cell.textLabel.text = netService.name;
    }
	
	return cell;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 1;
}

-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return [self.services count];
}

#pragma mark - NSNetServiceBrowserDelegate

-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing{
    if(![[[UIDevice currentDevice]name] isEqualToString:aNetService.name]){
        [self.services addObject:aNetService];
    }
    NSLog(@"did find service: %@", self.services);
    if(!moreComing){
        [self updateUI];
    }
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing{
    [self.services removeObject:aNetService];
    if(!moreComing){
        [self updateUI];
    }
}

-(void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)aNetServiceBrowser{
    _searching = YES;
}

-(void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)aNetServiceBrowser{
    _searching = NO;
}

-(void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict{
    _searching = NO;
    NSLog(@"netServiceBrowser ERROR: %@", errorDict);
}

#pragma mark - NSNetServiceDelegate

-(void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict{
    NSLog(@"ERROR: DID NOT RESOLVE: %@", errorDict);
    [self.tableView reloadData];
}

-(void)netServiceDidResolveAddress:(NSNetService *)netService{    
    if(!netService){
        [self setup];
        return;
    }
    
    if(![netService getInputStream:&_inStream outputStream:&_outStream]){
        NSLog(@"Failed connecting to server");
    }
    
    [netService stop];
    
    [self.view addSubview:self.cameraView];
    UINavigationItem *item = [self navigationItem];
    item.rightBarButtonItem = [[UIBarButtonItem alloc]initWithTitle:@"Close"
                                                              style:UIBarButtonItemStyleBordered
                                                             target:self action:@selector(close)];
    [[self view]setNeedsDisplay];
//    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc]initWithTitle:@"Close"
//                                                                   style:UIBarButtonItemStyleBordered
//                                                                  target:self action:@selector(close)];
//    [self.navigationController.navigationItem setRightBarButtonItem:closeButton];
    
    [self openStreams];
}

#pragma mark - TCPServer Delegate

-(void) serverDidEnableBonjour:(TCPServer*)server withName:(NSString*)name{
    NSLog(@"%@ did publish", name);
}
-(void) serverDidNotEnableBonjour:(TCPServer*)server withErrorDict:(NSDictionary*)errorDict{
    NSLog(@"serverDidNotEnableBonjour: %@", errorDict);
}
-(void) didAcceptConnectionForServer:(TCPServer*)thisServer inputStream:(NSInputStream*)istr outputStream:(NSOutputStream*)ostr{
    if (self.inStream || self.outStream || thisServer != self.server){
        return;
    }
    self.server = nil;
    
    self.inStream = istr;
    self.outStream = ostr;
    
    [self openStreams];
}

#pragma mark - Write Data

-(void)writeData:(NSData*)imageData withStream:(NSOutputStream*)oStream{
    NSLog(@"In write data");
    
    if([_writeDataBuffer length] == 0) manualWrite = YES;
    else manualWrite = NO;
    
    if([oStream hasSpaceAvailable] && [_writeDataBuffer length] > 0){
        NSLog(@"In write data: has space available");
        NSUInteger length = [_writeDataBuffer length];
        NSUInteger bytesWritten = [oStream write:[_writeDataBuffer bytes] maxLength:length];
        //NSLog(@"bytesWritten: %u", bytesWritten);
        if(bytesWritten == -1){
            NSLog(@"Error writing data");
        }
        else if(bytesWritten > 0){
            [_writeDataBuffer replaceBytesInRange:NSMakeRange(0, bytesWritten) withBytes:NULL length:0];
        }
    }
}

-(void)packageDataWithHeader:(NSData*)outgoingData{
    uint32_t header[1] = {YB_HEADER};
    uint32_t imageDataLength[1] = {[outgoingData length]};
    [_writeDataBuffer appendBytes:header length:sizeof(uint32_t)];
    [_writeDataBuffer appendBytes:imageDataLength length:sizeof(uint32_t)];
    [_writeDataBuffer appendBytes:[outgoingData bytes] length:[outgoingData length]];
}

-(void)writeDataToBuffer:(NSData*)imageData{
    if(_writeDataBuffer == nil){
        _writeDataBuffer = [[NSMutableData alloc]init];
    }
    [self packageDataWithHeader:imageData];
    if(manualWrite){
        [self writeData:imageData withStream:self.outStream];
    }
}

#pragma mark - Read Data

-(void)readData{
    NSLog(@"In read data");
    if([self.inStream hasBytesAvailable]){
        
        static uint8_t buffer[INPUT_BUFFER_SIZE];
        NSUInteger bytesRead = [self.inStream read:buffer maxLength:INPUT_BUFFER_SIZE];
        if(_readDataBuffer == nil){
            _readDataBuffer = [[NSMutableData alloc]init];
        }
        if(bytesRead  == -1){
            NSLog(@"ERROR read data");
        }
        else if(bytesRead > 0){
            [_readDataBuffer appendBytes:buffer length:bytesRead];
            _readDataBufferPosition += bytesRead;
            while(YES){
                if(_readDataBufferPosition < YBHeader_Length){
                    break;
                }
                YBHeader *ybHeader = (YBHeader*)[_readDataBuffer bytes];
                if([_readDataBuffer length] < ybHeader->imageDataLength){
                    break;
                }
                YBSegment *ybSegment = [[YBSegment alloc]initWithData:_readDataBuffer];
                _readDataBufferPosition -= ybSegment.ybSegmentLength;
                NSRange range = NSMakeRange(0, ybSegment.ybSegmentLength);
                [_readDataBuffer replaceBytesInRange:range withBytes:NULL length:0];
                UIImage *image = [UIImage imageWithData:ybSegment.imageData];
                if(image){
                    NSLog(@"Have image");
                    [self.videoImageView setImage:image];
                    break;
                }
            }
        }
    }
}

#pragma mark - NSStream Delegate

-(void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode{
    UIAlertView *alertView;
    switch(eventCode){
        case NSStreamEventOpenCompleted:
        {
            NSLog(@"NSStream Event Open Completed");
            
            break;
        }
        case NSStreamEventHasBytesAvailable:
        {
            if(_isStalker){
                if(aStream == self.inStream){
                    [self readData];
                }
            }
        }
        case NSStreamEventEndEncountered:
        {
            NSLog(@"NSStreamEventEndEncountered");
            if(!self.inStream || !self.outStream){
                alertView = [[UIAlertView alloc]initWithTitle:@"Other device disconnected!"
                                                      message:nil
                                                     delegate:self
                                            cancelButtonTitle:nil
                                            otherButtonTitles:@"Continue", nil];
                [alertView show];
                //isStalker = NO;
            }
            break;
        }
        case NSStreamEventErrorOccurred:
        {
            [self closeSessions];

            if(!self.inStream || !self.outStream){
                NSLog(@"NSStreamEventErrorOccured");
            }
            break;
            
        }
        case NSStreamEventHasSpaceAvailable:
        {
            if(!_isStalker){
                if(aStream == _outStream){
                    [self writeData:_writeDataBuffer withStream:_outStream];
                }
            }
        }
        case NSStreamEventNone:
        {
            
        }
    }
}


-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    
    if(!_isStalker){
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        //Lock the base address of the pixel buffer
        CVPixelBufferLockBaseAddress(imageBuffer, 0);
        
        //Get the number of bytes per row for the pixel buffer
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
        //Get the pixel buffer width and height
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        
        //Create a device dependent RGB color space
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        
        //Get the base address of the pixel buffer
        void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
        
        CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        CGImageRef newImage = CGBitmapContextCreateImage(newContext);
        CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
        
        //Make UIImage
        
        UIImage *image = [[UIImage alloc]initWithCGImage:newImage];
        
        //release
        CGContextRelease(newContext);
        CGColorSpaceRelease(colorSpace);
        CGImageRelease(newImage);
        if(self.outStream && image){
            NSData *imageData = UIImageJPEGRepresentation(image, 0.0);
            //[self writeData:imageData withStream:outStream];
            NSLog(@"imageData size: %d", [imageData length]);
            [self writeDataToBuffer:imageData];
        }
    }
}

-(void)close{
    [self.cameraView removeFromSuperview];
    UINavigationItem *item = [self navigationItem];
    item.rightBarButtonItem = nil;
    [[self view]setNeedsDisplay];
    [[NSNotificationCenter defaultCenter]postNotificationName:CAMERAVIEWDIDCLOSE object:nil];
}

-(void)closeSessions{
    [[NSNotificationCenter defaultCenter]removeObserver:self];
    [self closeStreams];
    [self.captureSession stopRunning];
    [self.serviceBrowser searchForServicesOfType:[TCPServer bonjourTypeFromIdentifier:SERVICE_NAME] inDomain:@"local"];
    [self setup];
}

@end
