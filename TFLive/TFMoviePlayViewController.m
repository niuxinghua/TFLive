//
//  TFMoviePlayViewController.m
//  TFLive
//
//  Created by wei shi on 2017/6/28.
//  Copyright © 2017年 wei shi. All rights reserved.
//

#import "TFMoviePlayViewController.h"
#import "TFLivePlayController.h"
#import "TFOPGLESDisplayView.h"

@interface TFMoviePlayViewController (){
    TFLivePlayController *_livePlayer;
}

@end

@implementation TFMoviePlayViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    self.view.backgroundColor = [UIColor whiteColor];
    NSURL *liveURL = [NSURL URLWithString:_liveAddr];
    
    _livePlayer = [[TFLivePlayController alloc] initWithLiveURL:liveURL];
    [_livePlayer prepareToPlay];
    
    //_livePlayer.playView.frame = CGRectMake(0, 100, 50, 100);
    _livePlayer.playView.frame = self.view.bounds;
    [self.view addSubview:_livePlayer.playView];
    
    
    {
        TFOPGLESDisplayView *renderView = (TFOPGLESDisplayView *)_livePlayer.playView;
        
        UIImage *image = [UIImage imageNamed:@"github"];
        CGImageRef imageRef = [image CGImage];
        NSUInteger width = CGImageGetWidth(imageRef);
        NSUInteger height = CGImageGetHeight(imageRef);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        unsigned char *rawData = malloc(height * width * 4);
        NSUInteger bytesPerPixel = 4;
        NSUInteger bytesPerRow = bytesPerPixel * width;
        NSUInteger bitsPerComponent = 8;
        CGContextRef context = CGBitmapContextCreate(rawData, width, height, bitsPerComponent, bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(colorSpace);
        
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        CGContextRelease(context);
        
        
        TFImageBuffer imageBuf;
        imageBuf.width = [image size].width;
        imageBuf.height = [image size].height;
        imageBuf.pixels[0] = rawData;
        
        
        //[renderView renderImageBuffer:&imageBuf];
    }
}

-(void)dealloc{
    [_livePlayer stop];
}

@end
