//
//  DAViewController.m
//  DAScratchPadExample
//
//  Created by David Levi on 5/31/13.
//  Copyright (c) 2013 Double Apps Inc. All rights reserved.
//

#import "DAViewController.h"
#import "DAScratchPadView.h"
#import <QuartzCore/QuartzCore.h>
#import "NSArray+JSON.h"
@interface DAViewController ()
@property (unsafe_unretained, nonatomic) IBOutlet DAScratchPadView *scratchPad;
@property (unsafe_unretained, nonatomic) IBOutlet UISlider *airbrushFlowSlider;
- (IBAction)setColor:(id)sender;
- (IBAction)setWidth:(id)sender;
- (IBAction)setOpacity:(id)sender;
- (IBAction)clear:(id)sender;
- (IBAction)selectImage:(id)sender;
- (IBAction)paint:(id)sender;
- (IBAction)airbrush:(id)sender;
- (IBAction)airbrushFlow:(id)sender;
@end

@implementation DAViewController
{
	NSInteger curImage;
	UIImage* images[3];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	curImage = 0;
	images[0] = nil;
	images[1] = nil;
	images[2] = nil;
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
		self.airbrushFlowSlider.transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(-M_PI/2.0f), -30.0f, -35.0f);
	}
    
    [self read];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
	[self setScratchPad:nil];
	[self setAirbrushFlowSlider:nil];
	[super viewDidUnload];
}

- (IBAction)setColor:(id)sender
{
	UIButton* button = (UIButton*)sender;
	self.scratchPad.drawColor = button.backgroundColor;
}

- (IBAction)setWidth:(id)sender
{
	UISlider* slider = (UISlider*)sender;
	self.scratchPad.drawWidth = slider.value;
}

- (IBAction)setOpacity:(id)sender
{
	UISlider* slider = (UISlider*)sender;
	self.scratchPad.drawOpacity = slider.value;
}

- (IBAction)clear:(id)sender
{
	[self.scratchPad clearToColor:[UIColor whiteColor]];
}

- (IBAction)selectImage:(id)sender
{
	images[curImage] = [self.scratchPad getSketch];
	UIButton* button = (UIButton*)sender;
	curImage = button.tag;
	[self.scratchPad setSketch:images[curImage]];
}

- (IBAction)paint:(id)sender
{
	self.scratchPad.toolType = DAScratchPadToolTypePaint;
}

- (IBAction)airbrush:(id)sender
{
	self.scratchPad.toolType = DAScratchPadToolTypeAirBrush;
}

- (IBAction)airbrushFlow:(id)sender
{
	UISlider* slider = (UISlider*)sender;
	self.scratchPad.airBrushFlow = slider.value;
}

- (IBAction)save:(id)sender {
    NSArray *paths = self.scratchPad.paths;
    NSString *str = [paths toReadableJSONString];
    
    NSFileManager *manager = [NSFileManager defaultManager];
    NSArray *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = [path objectAtIndex:0];
    NSString *filepath = [documents stringByAppendingPathComponent:@"paths.txt"];
    if ([manager createFileAtPath:filepath contents:nil attributes:nil]) {
        printf("文件创建成功");
    }
    else {
        printf("文件创建失败");
    }
    if (!documents) {
        printf("没有找到目录");
    }
    if ([str writeToFile:filepath atomically:YES encoding:NSUTF8StringEncoding error:nil]) {
        printf("文件写入成功");
    }
}

- (void)read {
    NSArray *path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = [path objectAtIndex:0];
    NSString *filepath = [documents stringByAppendingPathComponent:@"paths.txt"];
    NSString *str = [NSString stringWithContentsOfFile:filepath encoding:NSUTF8StringEncoding error:nil];
    
    NSArray *paths = [NSArray stringToJSON:str];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self.scratchPad autoDraw:paths];
    });
}

@end
