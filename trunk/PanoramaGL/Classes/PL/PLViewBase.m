/*
 * This file is part of the PanoramaGL library.
 *
 *  Author: Javier Baez <javbaezga@gmail.com>
 *
 *  $Id$
 *
 * This is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation; version 3 of
 * the License
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this software; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
 * 02110-1301 USA, or see the FSF site: http://www.fsf.org.
 */

#import "PLViewBase.h"

@interface PLViewBase ()

@property (nonatomic, assign) NSTimer *animationTimer;

- (void)allocAndInitVariables;
- (void)initializeValues;

- (BOOL)calculateFov:(NSSet *)touches;

- (BOOL)executeDefaultAction:(NSSet *)touches;
- (BOOL)executeDefaultAction:(NSSet *)touches isFovCalculated:(BOOL)isFovCalculated;

- (void)activateAccelerometer;
- (void)deactiveAccelerometer;

- (void)stopAnimationInternally;

- (void)startInertia;
- (void)stopInertia;
- (void)inertia;

- (void)activateOrientation;
- (void)deactiveOrientation;
- (void)changeOrientation:(UIDeviceOrientation)orientation;
- (void)orientationChanged:(UIDeviceOrientation)orientation;
- (BOOL)isOrientationValid:(UIDeviceOrientation)orientation;
- (UIDeviceOrientation)currentDeviceOrientation;

- (BOOL)isTouchInView:(NSSet *)touches;
- (CGPoint)getLocationOfFirstTouch:(NSSet *)touches;

- (void)drawViewInternally;

@end

@implementation PLViewBase

@synthesize animationTimer;
@synthesize animationInterval;

@synthesize isDeviceOrientationEnabled;
@synthesize deviceOrientation;
@synthesize deviceOrientationSupported;

@synthesize isAccelerometerEnabled, isAccelerometerLeftRightEnabled, isAccelerometerUpDownEnabled;
@synthesize accelerometerSensitivity;
@synthesize accelerometerInterval;

@synthesize startPoint, endPoint;

@synthesize isScrollingEnabled;
@synthesize minDistanceToEnableScrolling;

@synthesize isInertiaEnabled;
@synthesize inertiaInterval;

@synthesize isResetEnabled;

@synthesize delegate;

#pragma mark -
#pragma mark init methods 

- (id)initWithCoder:(NSCoder*)coder 
{
    
    if ((self = [super initWithCoder:coder])) 
	{
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
		[self allocAndInitVariables];
		[self initializeValues];
    }
    return self;
}

- (void)allocAndInitVariables
{
}

- (void)initializeValues
{
	animationInterval = kDefaultAnimationTimerInterval;
	
	isAccelerometerEnabled = NO;
	isAccelerometerLeftRightEnabled = YES;
	isAccelerometerUpDownEnabled = NO;
	accelerometerSensitivity = kDefaultAccelerometerSensitivity;
	accelerometerInterval = kDefaultAccelerometerInterval;
	
	isDeviceOrientationEnabled = NO;
	deviceOrientationSupported = PLOrientationSupportedAll;
	
	isScrollingEnabled = NO;
	minDistanceToEnableScrolling = kDefaultMinDistanceToEnableScrolling;
	
	isInertiaEnabled = YES;
	inertiaInterval = kDefaultInertiaInterval;
	
	isValidForTouch = NO;
	
	isResetEnabled = YES;
	
	[self reset];
}

- (void)reset
{
	[self stopAnimationInternally];
	[self stopInertia];
	isValidForFov = isValidForScrolling = isScrolling = isValidForInertia = isValidForOrientation = NO;
	startPoint = endPoint = CGPointMake(0.0f, 0.0f);
	fovDistance = 0.0f;
	if(isDeviceOrientationEnabled)
		self.deviceOrientation = [self currentDeviceOrientation];
}

#pragma mark -
#pragma mark layer method 

+ (Class)layerClass 
{
    return [CAEAGLLayer class];
}

#pragma mark -
#pragma mark draw methods 

- (void)drawView
{
	if(isScrolling && delegate && [delegate respondsToSelector:@selector(view:shouldScroll:endPoint:)] && ![delegate view:self shouldScroll:startPoint endPoint:endPoint])
			return;
	[self drawViewInternally];
	if(isScrolling && delegate && [delegate respondsToSelector:@selector(view:didScroll:endPoint:)])
		[delegate view:self didScroll:startPoint endPoint:endPoint];
}

- (void)drawViewInternally
{
}

- (void)drawViewNTimes:(NSUInteger)times
{
	for(int i = 0; i < times; i++)
		[self drawView];
}

- (void)layoutSubviews 
{
	[super layoutSubviews];
	[self activateOrientation];
	[self activateAccelerometer];
	[self drawViewNTimes:2];
}

#pragma mark -
#pragma mark animation methods 

- (void)startAnimation 
{
	self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:animationInterval target:self selector:@selector(drawView) userInfo:nil repeats:YES];
	if(isScrollingEnabled)
		isValidForScrolling = YES;
	[self stopInertia];
}

- (void)stopAnimation
{
	[self stopAnimationInternally];
	[self stopInertia];
}

- (void)stopAnimationInternally 
{
	if(animationTimer)
		[animationTimer invalidate];
    self.animationTimer = nil;
	
	if(isScrollingEnabled)
	{
		isValidForScrolling = NO;
		if(!isInertiaEnabled)
			isValidForTouch = NO;
	}
	else
		isValidForTouch = NO;
}

- (void)setAnimationTimer:(NSTimer *)newTimer 
{
    [animationTimer invalidate];
    animationTimer = newTimer;
}

- (void)setAnimationInterval:(NSTimeInterval)interval 
{    
    animationInterval = interval;
	if (animationTimer) 
	{
        [self stopAnimationInternally];
        [self startAnimation];
    }
}

#pragma mark -
#pragma mark action methods

- (BOOL)calculateFov:(NSSet *)touches
{
	if([touches count] == 2)
	{
		CGPoint point0 = [[[touches allObjects] objectAtIndex:0] locationInView:self];
		CGPoint point1 = [[[touches allObjects] objectAtIndex:1] locationInView:self];
		
		float distance = [PLMath distanceBetweenPoints:point0 :point1];
		
		startPoint = point0;
		endPoint = point1;
		
		distance = ABS(fovDistance) <= distance ? distance : -distance;
		BOOL isZoomIn = (distance >= 0);
		BOOL isCancelable = NO;
		
		if(delegate && [delegate respondsToSelector:@selector(view:shouldRunZooming:isZoomIn:isZoomOut:)])
			isCancelable = [delegate view:self shouldRunZooming:distance isZoomIn:isZoomIn isZoomOut:!isZoomIn];
				
		if(!isCancelable)
		{
			fovDistance = distance;
			if(delegate && [delegate respondsToSelector:@selector(view:didRunZooming:isZoomIn:isZoomOut:)])
				[delegate view:self didRunZooming:fovDistance isZoomIn:isZoomIn isZoomOut:!isZoomIn];
		}
		return YES;
	}
	return NO;
}

- (BOOL)executeDefaultAction:(NSSet *)touches
{
	return [self executeDefaultAction: touches isFovCalculated:YES];
}

- (BOOL)executeDefaultAction:(NSSet *)touches isFovCalculated:(BOOL)isFovCalculated
{
	if(isValidForFov)
		[self calculateFov:touches];
	else
	{
		BOOL isCancelable = NO;
		switch ([touches count]) 
		{
			case 3:
				if(isResetEnabled)
				{
					if(delegate && [delegate respondsToSelector:@selector(viewShouldReset:)])
						isCancelable = [delegate viewShouldReset:self];
					if(!isCancelable)
					{
						[self reset];
						[self drawView];
						if(delegate && [delegate respondsToSelector:@selector(viewDidReset:)])
							[delegate viewDidReset:self];
					}
				}
				break;
			case 2:
				if(delegate && [delegate respondsToSelector:@selector(viewShouldBeginZooming:)])
					isCancelable = [delegate viewShouldBeginZooming:self];
				if(!isCancelable)
				{
					isValidForFov = YES;
					if(isFovCalculated)
						[self calculateFov:touches];
					if(delegate && [delegate respondsToSelector:@selector(view:didBeginZooming:endPoint:)])
						[delegate view:self didBeginZooming:[[[touches allObjects] objectAtIndex:0] locationInView:self] endPoint:[[[touches allObjects] objectAtIndex:1] locationInView:self]];
				}
			default:
				return NO;
		}
	}
	return YES;
}

#pragma mark -
#pragma mark touch methods

- (BOOL)isTouchInView:(NSSet *)touches
{
	for(UITouch *touch in touches)
		if(touch.view != self)
			return NO;
	return YES;
}

- (CGPoint)getLocationOfFirstTouch:(NSSet *)touches
{
	UITouch *touch = [[touches allObjects] objectAtIndex:0];
	return [touch locationInView:touch.view];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{	
	if(![self isTouchInView:touches])
		return;
	
	if(delegate && [delegate respondsToSelector:@selector(view:shouldBeginTouching:withEvent:)] && ![delegate view:self shouldBeginTouching:touches withEvent:event])
		return;
	
	tapCount += [touches count];
	
	if(isValidForFov)
		return;
	
	[self stopInertia];
	if([[touches anyObject] tapCount] == 2)
	{
		if(isValidForScrolling)
		{
			[self stopAnimationInternally];
			isScrolling = NO;
			
			if(delegate && [delegate respondsToSelector:@selector(view:didEndScrolling:endPoint:)])
				[delegate view:self didEndScrolling:startPoint endPoint:endPoint];
			
			return;
		}
	}
	
	isValidForTouch = YES;
	
	if(![self executeDefaultAction:touches isFovCalculated:NO])
	{
		startPoint = endPoint = [self getLocationOfFirstTouch:touches];
		[self startAnimation];
	}
	
	if(delegate && [delegate respondsToSelector:@selector(view:didBeginTouching:withEvent:)])
		[delegate view:self didBeginTouching:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	if(![self isTouchInView:touches])
		return;
	
	if(delegate && [delegate respondsToSelector:@selector(view:shouldTouch:withEvent:)] && ![delegate view:self shouldTouch:touches withEvent:event])
		return;
	
	if(![self executeDefaultAction:touches])
		endPoint = [self getLocationOfFirstTouch:touches];
	
	if(delegate && [delegate respondsToSelector:@selector(view:didTouch:withEvent:)])
		[delegate view:self didTouch:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{ 	
	if(![self isTouchInView:touches])
		return;
	
	if(delegate && [delegate respondsToSelector:@selector(view:shouldEndTouching:withEvent:)] && ![delegate view:self shouldEndTouching:touches withEvent:event])
		return;
	
	tapCount -= [touches count];
	
	if(isValidForFov)
	{
		if(tapCount == 0)
		{
			[self stopAnimationInternally];
			isValidForFov = isValidForTouch = NO;
			startPoint = endPoint = CGPointMake(0.0f, 0.0f);
		}
	}
	else 
	{
		if(![self executeDefaultAction:touches isFovCalculated:NO])
		{
			endPoint = [self getLocationOfFirstTouch:touches];
			BOOL isCancelable = NO;
				
			if(isScrollingEnabled && delegate && [delegate respondsToSelector:@selector(view:shouldBeingScrolling:endPoint:)])
				isCancelable = [delegate view:self shouldBeingScrolling:startPoint endPoint:endPoint];
				
			if(isScrollingEnabled && !isCancelable)
			{
				BOOL isValidForMove = ((startPoint.x == endPoint.x && startPoint.y == endPoint.y) || [PLMath distanceBetweenPoints:startPoint :endPoint] <= minDistanceToEnableScrolling);
				if(isInertiaEnabled)
				{
					[self stopAnimationInternally];
					if(isValidForMove)
						isValidForTouch = NO;
					else
					{
						isCancelable = NO;
						if(delegate && [delegate respondsToSelector:@selector(view:shouldBeginInertia:endPoint:)])
							isCancelable = [delegate view:self shouldBeginInertia:startPoint endPoint:endPoint];
						if(!isCancelable)
							[self startInertia];
					}
				}
				else
				{
					if(isValidForMove)
						[self stopAnimationInternally];
					else
					{
						isScrolling = YES;
						if(delegate && [delegate respondsToSelector:@selector(view:didBeginScrolling:endPoint:)])
							[delegate view:self didBeginScrolling:startPoint endPoint:endPoint];
					}
				}
			}
			else
			{
				startPoint = endPoint;
				[self stopAnimationInternally];
				if(delegate && [delegate respondsToSelector:@selector(view:didEndMoving:endPoint:)])
					[delegate view:self didEndMoving:startPoint endPoint:endPoint];
			}
		}
	}
	
	if(delegate && [delegate respondsToSelector:@selector(view:didEndTouching:withEvent:)])
		[delegate view:self didEndTouching:touches withEvent:event];
}

#pragma mark -
#pragma mark inertia methods

- (void)startInertia
{
	[self stopInertia];
	float interval = inertiaInterval / [PLMath distanceBetweenPoints:startPoint :endPoint];
	if(interval < 0.01f)
	{
		inertiaStepValue = 0.01f / interval;
		interval = 0.01f;
	}
	else
		inertiaStepValue = 1.0f;
	inertiaTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(inertia) userInfo:nil repeats:YES];
	
	if(delegate && [delegate respondsToSelector:@selector(view:didBeginInertia:endPoint:)])
		[delegate view:self didBeginInertia:startPoint endPoint:endPoint];
}

- (void)stopInertia
{
	if(inertiaTimer)
		[inertiaTimer invalidate];
	inertiaTimer = nil;
}

- (void)inertia
{
	if(delegate && [delegate respondsToSelector:@selector(view:shouldRunInertia:endPoint:)] && ![delegate view:self shouldRunInertia:startPoint endPoint:endPoint])
		return;
	
	float m = (endPoint.y - startPoint.y) / (endPoint.x - startPoint.x);
	float b = (startPoint.y * endPoint.x - endPoint.y * startPoint.x) / (endPoint.x - startPoint.x);
	float x, y, add;
	
	if(ABS(endPoint.x - startPoint.x) >= ABS(endPoint.y - startPoint.y))
	{
		add = (endPoint.x > startPoint.x ? -inertiaStepValue : inertiaStepValue);
		x = endPoint.x + add;
		if((add > 0.0f && x > startPoint.x) || (add <= 0.0f && x < startPoint.x))
		{
			[self stopInertia];
			isValidForTouch = NO;
			
			if(delegate && [delegate respondsToSelector:@selector(view:didEndInertia:endPoint:)])
				[delegate view:self didEndInertia:startPoint endPoint:endPoint];
			
			return;
		}
		y = m * x + b;
	}
	else
	{
		add = (endPoint.y > startPoint.y ? -inertiaStepValue : inertiaStepValue);
		y = endPoint.y + add;
		if((add > 0.0f && y > startPoint.y) || (add <= 0.0f && y < startPoint.y))
		{
			[self stopInertia];
			isValidForTouch = NO;
			
			if(delegate && [delegate respondsToSelector:@selector(view:didEndInertia:endPoint:)])
				[delegate view:self didEndInertia:startPoint endPoint:endPoint];
			
			return;
		}
		x = (y - b)/m;
	}
	endPoint = CGPointMake(x, y);
	[self drawView];
	
	if(delegate && [delegate respondsToSelector:@selector(view:didRunInertia:endPoint:)])
		[delegate view:self didRunInertia:startPoint endPoint:endPoint];
}

#pragma mark -
#pragma mark accelerometer methods

- (void)setAccelerometerInterval:(NSTimeInterval)value
{
	accelerometerInterval = value;
	[self activateAccelerometer];
}

- (void)setAccelerometerSensitivity:(float)value
{
	accelerometerSensitivity = [PLMath valueInRange:value range:PLRangeMake(kAccelerometerSensitivityMinValue, kAccelerometerSensitivityMaxValue)];
}

- (void)activateAccelerometer
{
	UIAccelerometer* accelerometer = [UIAccelerometer sharedAccelerometer];
	if(accelerometer)
	{
		accelerometer.updateInterval = accelerometerInterval;
		accelerometer.delegate = self;
	}
	else
		NSLog(@"Accelerometer not running on the device!");
}

- (void)deactiveAccelerometer
{
	UIAccelerometer* accelerometer = [UIAccelerometer sharedAccelerometer];
	if(accelerometer)
		accelerometer.delegate = nil;
}
 
- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
	if(isValidForTouch || isValidForOrientation)
		return;
	
	if(isAccelerometerEnabled)
	{
		if(delegate && [delegate respondsToSelector:@selector(view:shouldAccelerate:withAccelerometer:)] && ![delegate view:self shouldAccelerate:acceleration withAccelerometer:accelerometer])
			return;
		
		UIAccelerationValue x = 0, y = 0;
		float factor = kAccelerometerMultiplyFactor * accelerometerSensitivity;
		if(isDeviceOrientationEnabled)
		{
			switch (deviceOrientation) 
			{
				case UIDeviceOrientationUnknown:
				case UIDeviceOrientationPortrait:
				case UIDeviceOrientationPortraitUpsideDown:
					x = (isAccelerometerLeftRightEnabled ? acceleration.x : 0.0f);
					y = (isAccelerometerUpDownEnabled ? acceleration.z : 0.0f);
					startPoint = CGPointMake(self.bounds.size.width / 2.0f, self.bounds.size.height / 2.0f);
					break;
				case UIDeviceOrientationLandscapeLeft:
				case UIDeviceOrientationLandscapeRight:
					x = (isAccelerometerUpDownEnabled ? -acceleration.z : 0.0f);
					y = (isAccelerometerLeftRightEnabled ? -acceleration.y : 0.0f);
					startPoint = CGPointMake(self.bounds.size.height / 2.0f, self.bounds.size.width / 2.0f);
					break;
				default:
					startPoint = CGPointMake(self.bounds.size.width / 2.0f, self.bounds.size.height / 2.0f);
					break;
			}
		}
		else 
		{
			UIDeviceOrientation currentOrientation = [self currentDeviceOrientation];
			switch (currentOrientation) 
			{
				case UIDeviceOrientationUnknown:
				case UIDeviceOrientationPortrait:
				case UIDeviceOrientationPortraitUpsideDown:
					x = (isAccelerometerLeftRightEnabled ? acceleration.x : 0.0f);
					y = (isAccelerometerUpDownEnabled ? acceleration.z : 0.0f);
					startPoint = CGPointMake(self.bounds.size.width / 2.0f, self.bounds.size.height / 2.0f);
					if(currentOrientation == UIDeviceOrientationPortraitUpsideDown)
					{
						x = -x;
						y = -y;
					}
					break;
				case UIDeviceOrientationLandscapeLeft:
				case UIDeviceOrientationLandscapeRight:
					x = (isAccelerometerLeftRightEnabled ? -acceleration.y : 0.0f);
					y = (isAccelerometerUpDownEnabled ? -acceleration.z : 0.0f);
					startPoint = CGPointMake(self.bounds.size.height / 2.0f, self.bounds.size.width / 2.0f);
					if(currentOrientation == UIDeviceOrientationLandscapeRight)
					{
						x = -x;
						y = -y;
					}
					break;
				default:
					startPoint = CGPointMake(self.bounds.size.width / 2.0f, self.bounds.size.height / 2.0f);
					break;
			}
		}

		endPoint = CGPointMake(startPoint.x + (x * factor), startPoint.y + (y * factor));
		[self drawView];
		
		if(delegate && [delegate respondsToSelector:@selector(view:didAccelerate:withAccelerometer:)])
			[delegate view:self didAccelerate:acceleration withAccelerometer:accelerometer];
	}
}

#pragma mark -
#pragma mark orientation methods

- (void)setDeviceOrientation:(UIDeviceOrientation)orientation
{
	if(deviceOrientation != orientation && [self isOrientationValid:orientation])
	{
		deviceOrientation = orientation;
		[self changeOrientation: orientation];
	}
}

- (void)activateOrientation
{
	[[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(didRotate:)
												 name:@"UIDeviceOrientationDidChangeNotification" object:nil];
}

- (void)deactiveOrientation
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

- (void)didRotate:(NSNotification *)notification
{
	if(isDeviceOrientationEnabled && [self isOrientationValid:[self currentDeviceOrientation]])
	{
		if(delegate && [delegate respondsToSelector:@selector(view:shouldRotate:)] && ![delegate view:self shouldRotate:[self currentDeviceOrientation]])
			return;
		
		deviceOrientation = [self currentDeviceOrientation];
		[self changeOrientation: deviceOrientation];
		
		if(delegate && [delegate respondsToSelector:@selector(view:didRotate:)])
			[delegate view:self didRotate:deviceOrientation];
	}
}

- (void)changeOrientation:(UIDeviceOrientation)orientation
{
	isValidForOrientation = YES;
	[self orientationChanged: orientation];
	[self drawView];
	isValidForOrientation = NO;
}

- (void)orientationChanged:(UIDeviceOrientation)orientation
{
}

- (BOOL)isOrientationValid:(UIDeviceOrientation)orientation
{
	PLOrientationSupported value;
	switch (orientation) 
	{
		case UIDeviceOrientationUnknown:
		case UIDeviceOrientationPortrait:
			value = PLOrientationSupportedPortrait;
			break;
		case UIDeviceOrientationPortraitUpsideDown:
			value = PLOrientationSupportedPortraitUpsideDown;
			break;
		case UIDeviceOrientationLandscapeLeft:
			value = PLOrientationSupportedLandscapeLeft;
			break;
		case UIDeviceOrientationLandscapeRight:
			value = PLOrientationSupportedLandscapeRight;
			break;
		default:
			return NO;
	}
	return (deviceOrientationSupported & value);
}

- (UIDeviceOrientation)currentDeviceOrientation
{
	return [[UIDevice currentDevice] orientation];
}

#pragma mark -
#pragma mark dealloc methods

- (void)dealloc 
{
	[self stopAnimation];
	[self deactiveOrientation];
	[self deactiveAccelerometer];
	[super dealloc];
}
				
@end
