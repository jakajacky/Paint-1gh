//
//  DAScratchpadView.m
//  DAScratchPad
//
//  Created by David Levi on 5/9/13.
//  Copyright 2013 Double Apps Inc. All rights reserved.
//

#import "DAScratchPadView.h"
#import <QuartzCore/QuartzCore.h>

#define PaintWithGPU 1   // GPU硬件加速使之线条更细腻、但是笔画多了之后手机发烫，卡顿

@interface DAScratchPadView ()
{
    CGFloat _drawOpacity;
    CGFloat _airBrushFlow;
    CALayer* drawLayer;
    UIImage* mainImage;
    UIImage* drawImage;
    CGPoint currentPoint;   // 当前point
    CGPoint lastPoint;      // 前一个point
    CGPoint previousPoint1; // 前前一个point
    CGPoint previousPoint2;
    CGPoint airbrushPoint;
    NSTimer* airBrushTimer;
    UIImage* airBrushImage;
    NSArray *points_ter;
    CADisplayLink *link;
    NSTimer *timer;
    NSTimer *timer_point;
    int j;
    
    CAShapeLayer *_slayer;
    UIBezierPath *_path;
}

@property (nonatomic, strong) NSUndoManager *undoManager;
@property (nonatomic, strong) NSMutableArray *points;

-(void)undo;

@end

@implementation DAScratchPadView
@synthesize undoManager;

- (void) initCommon
{
    _paths = [NSMutableArray array];
    _points = [NSMutableArray array];
    
	_toolType = DAScratchPadToolTypePaint;
	_drawColor = [UIColor blackColor];
	_drawWidth = 5.0f;
	_drawOpacity = 1.0f;
	_airBrushFlow = 0.5f;
	drawLayer = [[CALayer alloc] init];
	drawLayer.frame = CGRectMake(0.0f, 0.0f, self.layer.frame.size.width, self.layer.frame.size.height);
	mainImage = nil;
	drawImage = nil;
	airBrushTimer = nil;
	airBrushImage = nil;
	[self.layer addSublayer:drawLayer];
	[self clearToColor:self.backgroundColor];
    
    
    
    
    [self initShapeLayer];
}

- (id) initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
		[self initCommon];
	}
    return self;
}

- (void)initShapeLayer {
    _path = [[UIBezierPath alloc] init];
    _path.lineWidth = 5;
    _path.lineCapStyle = kCGLineCapRound; //线条拐角
    _path.lineJoinStyle = kCGLineCapRound; //终点处理
    
    _slayer = [CAShapeLayer layer];
    _slayer.path = _path.CGPath;
    _slayer.backgroundColor = [UIColor clearColor].CGColor;
    _slayer.fillColor = [UIColor clearColor].CGColor;
    _slayer.lineCap = kCALineCapRound;
    _slayer.lineJoin = kCALineJoinRound;
    _slayer.strokeColor = [UIColor blackColor].CGColor;
    _slayer.opacity = self.drawOpacity;
    _slayer.lineWidth = _path.lineWidth;
    [drawLayer addSublayer:_slayer];
}

- (id) initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder])) {
		[self initCommon];
	}
	return self;
}

- (void) layoutSubviews
{
	drawLayer.frame = CGRectMake(0.0f, 0.0f, self.layer.frame.size.width, self.layer.frame.size.height);
}

- (CGFloat) drawOpacity
{
	return _drawOpacity;
}

- (void) setDrawOpacity:(CGFloat)drawOpacity
{
	_drawOpacity = drawOpacity;
    _slayer.opacity = _drawOpacity;
}

- (CGFloat) airBrushFlow
{
	return _airBrushFlow;
}

- (void) setAirBrushFlow:(CGFloat)airBrushFlow
{
	_airBrushFlow = MIN(MAX(airBrushFlow, 0.0f), 1.0f);
}

// 计算中间点
CGPoint midPoint1(CGPoint p1, CGPoint p2)
{
    return CGPointMake((p1.x + p2.x) * 0.5, (p1.y + p2.y) * 0.5);
}

- (void) drawLineFrom:(CGPoint)from to:(CGPoint)to width:(CGFloat)width begin:(BOOL)isbegin
{
    NSLog(@"开始：(%f,%f) ++ 结束：(%f,%f)",from.x,from.y, to.x,to.y);
    CGPoint mid1 = midPoint1(from, previousPoint1);
    CGPoint mid2 = midPoint1(from, to);
    
    // 保存数据
    NSDictionary *point_start = @{@"x":@(mid1.x),
                                  @"y":@(mid1.y)};
    NSDictionary *point_end   = @{@"x":@(mid2.x),
                                  @"y":@(mid2.y)};
    [_points addObject:point_start];
    [_points addObject:point_end];
    if (PaintWithGPU) {
        [_path moveToPoint:mid1];
        [_path addQuadCurveToPoint:mid2 controlPoint:lastPoint];
    }
    else {
        UIGraphicsBeginImageContext(self.frame.size);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextScaleCTM(ctx, 1.0f, -1.0f);
        CGContextTranslateCTM(ctx, 0.0f, -self.frame.size.height);
        if (drawImage != nil) {
            CGRect rect = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);
            CGContextDrawImage(ctx, rect, drawImage.CGImage);
        }
        CGContextSetLineCap(ctx, kCGLineCapRound);
        CGContextSetLineJoin(ctx, kCGLineJoinRound);
        CGContextSetLineWidth(ctx, width);
        CGContextSetStrokeColorWithColor(ctx, self.drawColor.CGColor);

        CGContextMoveToPoint(ctx, mid1.x, mid1.y);
        CGContextAddQuadCurveToPoint(ctx, lastPoint.x, lastPoint.y, mid2.x, mid2.y);

        CGContextStrokePath(ctx);
        CGContextFlush(ctx);
        drawImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        drawLayer.contents = (id)drawImage.CGImage;
    }
}

- (void) drawImage:(UIImage*)image at:(CGPoint)point
{
	UIGraphicsBeginImageContext(self.frame.size);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextScaleCTM(ctx, 1.0f, -1.0f);
	CGContextTranslateCTM(ctx, 0.0f, -self.frame.size.height);
	if (drawImage != nil) {
		CGRect rect = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);
		CGContextDrawImage(ctx, rect, drawImage.CGImage);
	}
	CGRect rect = CGRectMake(point.x - (image.size.width / 2.0f),
							 point.y - (image.size.height / 2.0f),
							 image.size.width, image.size.height);
	CGContextDrawImage(ctx, rect, image.CGImage);
	CGContextFlush(ctx);
	drawImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	drawLayer.contents = (id)drawImage.CGImage;
}

- (void) drawImage:(UIImage*)image from:(CGPoint)fromPoint to:(CGPoint)toPoint
{
	CGFloat dx = toPoint.x - fromPoint.x;
	CGFloat dy = toPoint.y - fromPoint.y;
	CGFloat len = sqrtf((dx*dx)+(dy*dy));
	CGFloat ix = dx/len;
	CGFloat iy = dy/len;
	CGPoint point = fromPoint;
	int ilen = (int)len;

	UIGraphicsBeginImageContext(self.frame.size);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextScaleCTM(ctx, 1.0f, -1.0f);
	CGContextTranslateCTM(ctx, 0.0f, -self.frame.size.height);
	if (drawImage != nil) {
		CGRect rect = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);
		CGContextDrawImage(ctx, rect, drawImage.CGImage);
	}
	for (int i = 0; i < ilen; i++) {
		CGRect rect = CGRectMake(point.x - (image.size.width / 2.0f),
								 point.y - (image.size.height / 2.0f),
								 image.size.width, image.size.height);
		CGContextDrawImage(ctx, rect, image.CGImage);
		point.x += ix;
		point.y += iy;
	}
	CGContextFlush(ctx);
	drawImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	drawLayer.contents = (id)drawImage.CGImage;
}

- (void) commitDrawingWithOpacity:(CGFloat)opacity
{
	UIGraphicsBeginImageContext(self.frame.size);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGContextScaleCTM(ctx, 1.0f, -1.0f);
	CGContextTranslateCTM(ctx, 0.0f, -self.frame.size.height);
	CGRect rect = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);
	if (mainImage != nil) {
		CGContextDrawImage(ctx, rect, mainImage.CGImage);
	}
	CGContextSetAlpha(ctx, opacity);
	CGContextDrawImage(ctx, rect, drawImage.CGImage);
	mainImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
	
	self.layer.contents = (id)mainImage.CGImage;
    drawLayer.contents = nil;
	drawImage = nil;
}

- (void)paintTouchesBegan
{
	[self drawLineFrom:lastPoint to:lastPoint width:self.drawWidth begin:NO];
    _slayer.path = _path.CGPath;
    _slayer.strokeColor = self.drawColor.CGColor;
}

- (void)paintTouchesMoved
{
	[self drawLineFrom:lastPoint to:currentPoint width:self.drawWidth begin:YES];
    if (PaintWithGPU && !_isAutoPlay) {
        _slayer.path = _path.CGPath;
    }
}

- (void) paintTouchesEnded
{
    NSMutableDictionary *path = [NSMutableDictionary dictionary];
    [path setValue:[_points copy] forKey:@"coor"];
    NSLog(@"地址%p",path);
    [_paths addObject:path];
    if (PaintWithGPU) {
        [self initShapeLayer];
    }
    else {
        [self commitDrawingWithOpacity:self.drawOpacity];
    }
}

- (void) airBrushTimerExpired:(NSTimer*)timer
{
	if ((lastPoint.x == airbrushPoint.x) && (lastPoint.y == airbrushPoint.y)) {
		[self drawImage:airBrushImage at:lastPoint];
	}
	airbrushPoint = lastPoint;
}

- (void) airBrushTouchesBegan
{
	UIGraphicsBeginImageContext(CGSizeMake(self.drawWidth, self.drawWidth));
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGFloat wd = self.drawWidth / 2.0f;
	CGPoint pt = CGPointMake(wd, wd);
	CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
	size_t num_locations = 2;
	CGFloat locations[2] = { 1.0, 0.0 };
	CGFloat* comp = (CGFloat *)CGColorGetComponents(self.drawColor.CGColor);
	CGFloat fc = sinf(((self.airBrushFlow/5.0f)*M_PI)/2.0f);
	CGFloat colors[8] = { comp[0], comp[1], comp[2], 0.0f, comp[0], comp[1], comp[2], fc };
	CGGradientRef gradient = CGGradientCreateWithColorComponents(colorspace, colors, locations, num_locations);
	CGContextDrawRadialGradient(ctx, gradient, pt, 0.0f, pt, wd, 0);
	CGContextFlush(ctx);
	airBrushImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	CFRelease(gradient);
	CFRelease(colorspace);
	
	airbrushPoint = CGPointMake(-5000.0f, -5000.0f);
	airBrushTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f / 60.0f
													 target:self
												   selector:@selector(airBrushTimerExpired:)
												   userInfo:nil
													repeats:YES];
}

- (void) airBrushTouchesMoved
{
	[self drawImage:airBrushImage from:lastPoint to:currentPoint];
}

- (void) airBrushTouchesEnded
{
	[airBrushTimer invalidate];
	airBrushTimer = nil;
	airBrushImage = nil;
	[self commitDrawingWithOpacity:self.drawOpacity];
}

- (void)autoDraw:(NSArray *)paths {
    _isAutoPlay = YES;
    __block int i = 0;
    timer = [NSTimer scheduledTimerWithTimeInterval:0.75 repeats:YES block:^(NSTimer * _Nonnull timer) {
        if (i>=paths.count) {
            [timer invalidate];
            timer = nil;
            _isAutoPlay = NO;
            [self initShapeLayer];
            return;
        }
        NSDictionary *path = paths[i];
        points_ter = path[@"coor"];
        // Brgan
        NSDictionary *point_first = points_ter[0];
        lastPoint = CGPointMake([point_first[@"x"] floatValue], [point_first[@"y"] floatValue]);
        previousPoint1 = CGPointMake([point_first[@"x"] floatValue], [point_first[@"y"] floatValue]);
        [self paintTouchesBegan];
        // Move
        if (PaintWithGPU) {
            for (int j = 1; j<points_ter.count; j++) {
                NSDictionary *point = points_ter[j];
                currentPoint = CGPointMake([point[@"x"] floatValue], [point[@"y"] floatValue]);
                [self paintTouchesMoved];
    
                previousPoint1 = lastPoint;
                lastPoint = currentPoint;
            }
            _slayer.path = _path.CGPath;
            switch (i%5) {
                case 0:
                    _slayer.strokeColor = [UIColor colorWithWhite:0 alpha:1].CGColor;
                    break;
                case 1:
                    _slayer.strokeColor = [UIColor redColor].CGColor;
                    break;
                case 2:
                    _slayer.strokeColor = [UIColor blueColor].CGColor;
                    break;
                case 3:
                    _slayer.strokeColor = [UIColor greenColor].CGColor;
                    break;
                case 4:
                    _slayer.strokeColor = [UIColor yellowColor].CGColor;
                default:
                    break;
            }
            CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            pathAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
            pathAnimation.duration = 0.75;
            pathAnimation.repeatCount = 1;
            pathAnimation.fromValue = [NSNumber numberWithFloat:0.0f];
            pathAnimation.toValue = [NSNumber numberWithFloat:1.0f];
            [_slayer addAnimation:pathAnimation forKey:@"strokeEnd"];
            
            // End
            [self paintTouchesEnded];
        }
        else {
            j=0;
            timer_point = [NSTimer scheduledTimerWithTimeInterval:1.0/points_ter.count target:self selector:@selector(move) userInfo:nil repeats:YES];
            [[NSRunLoop mainRunLoop] addTimer:timer_point forMode:NSRunLoopCommonModes];
        }
        i += 1;
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)move {
    [timer setFireDate:[NSDate distantFuture]];
    if (j>=points_ter.count) {
        // End
        [self paintTouchesEnded];
        // 重置参数
        j=0;
        [timer_point invalidate];
        timer_point = nil;
        [timer setFireDate:[NSDate date]];
        return;
    }
    NSDictionary *point = points_ter[j];
    currentPoint = CGPointMake([point[@"x"] floatValue], [point[@"y"] floatValue]);
    [self paintTouchesMoved];
    
    previousPoint1 = lastPoint;
    lastPoint = currentPoint;
    
    j++;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!self.userInteractionEnabled) {
		[super touchesBegan:touches withEvent:event];
		return;
	}
	
	UITouch *touch = [touches anyObject];
	lastPoint = [touch locationInView:self];
    previousPoint1 = [touch locationInView:self];
    if (PaintWithGPU) {
    }
    else {
        previousPoint1.y = self.frame.size.height - previousPoint1.y;
        lastPoint.y = self.frame.size.height - lastPoint.y;
    }
	
	if (self.toolType == DAScratchPadToolTypePaint) {
		[self paintTouchesBegan];
	}
	if (self.toolType == DAScratchPadToolTypeAirBrush) {
		[self airBrushTouchesBegan];
	}
}


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	if (!self.userInteractionEnabled) {
		[super touchesMoved:touches withEvent:event];
		return;
	}

	UITouch *touch = [touches anyObject];	
	currentPoint = [touch locationInView:self];
    if (PaintWithGPU) {
    }
    else {
        currentPoint.y = self.frame.size.height - currentPoint.y;
    }

	if (self.toolType == DAScratchPadToolTypePaint) {
		[self paintTouchesMoved];
	}
	if (self.toolType == DAScratchPadToolTypeAirBrush) {
		[self airBrushTouchesMoved];
	}

    previousPoint1 = lastPoint;
	lastPoint = currentPoint;
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!self.userInteractionEnabled) {
		[super touchesEnded:touches withEvent:event];
		return;
	}
	
	if (self.toolType == DAScratchPadToolTypePaint) {
		[self paintTouchesEnded];
	}
	if (self.toolType == DAScratchPadToolTypeAirBrush) {
		[self airBrushTouchesEnded];
	}
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	if (!self.userInteractionEnabled) {
		[super touchesCancelled:touches withEvent:event];
		return;
	}
	[self touchesEnded:touches withEvent:event];
}

- (void) clearToColor:(UIColor*)color
{
	UIGraphicsBeginImageContext(self.frame.size);
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	CGRect rect = CGRectMake(0.0f, 0.0f, self.frame.size.width, self.frame.size.height);
	CGContextSetFillColorWithColor(ctx, color.CGColor);
	CGContextFillRect(ctx, rect);
	CGContextFlush(ctx);
	mainImage = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	self.layer.contents = mainImage;
}


- (UIImage*) getSketch;
{
	return mainImage;
}

- (void) setSketch:(UIImage*)sketch
{
	mainImage = sketch;
	self.layer.contents = (id)sketch.CGImage;
}

@end
