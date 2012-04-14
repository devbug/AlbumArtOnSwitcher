//
//  AlbumArtOnSwitcher
//  
//  
//  Copyright (c) 2011-2012 deVbug
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <CoreGraphics/CoreGraphics.h>

#include <sys/types.h>
#include <sys/sysctl.h>



#define MOBILEIPOD_ID							((this_device & DeviceTypeiPad) != 0 ? @"com.apple.Music" : @"com.apple.mobileipod")
#define DEFAULT_AA_SIZE							((this_device & DeviceTypeiPad) != 0 ? 76 : 60)
#define DEFAULT_AA_VARIANT						((this_device & DeviceTypeRetina) != 0 ? 15 : ((this_device & DeviceTypeiPad) != 0 ? 1 : 0))


typedef NSUInteger DeviceType;
enum {
	DeviceTypeUnsupported		= 0,					// 00000000(2)
											// no retina
	DeviceTypeiPodTouch3g		= 1 << 0,				// 00000001(2)
	DeviceTypeiPhone3Gs			= 1 << 1,				// 00000010(2)
	DeviceTypeiPad				= 1 << 2,				// 00000100(2)
											// retina
	DeviceTypeiPodTouch4g		= 1 << 3,				// 00001000(2)
	DeviceTypeiPhone4			= 1 << 4,				// 00010000(2)
	DeviceTypeiPad3g			= 1 << 5,				// 00100000(2)
	
											// 
	DeviceTypeUnknown			= 0,					// 00000000(2)
	DeviceTypeNoRetina			= 7 << 0,				// 00000111(2)
	DeviceTypeRetina			= 7 << 1,				// 00111000(2)
};

static DeviceType this_device = DeviceTypeiPhone4;



extern "C" CGImageRef LICreateIconForImage(CGImageRef image, int variant, int precomposed);


static UIImage *iPodArtwork = nil;
static UIImage *nowPlayingArtwork = nil;
static UIImageView *nowPlayingView = nil;


@interface SBApplication : NSObject
- (NSString *)displayIdentifier;
@end

@interface SBIconImageContainerView : UIView
@end

@interface SBIconView : UIView {
	SBIconImageContainerView *_iconImageContainer;
}
- (UIImageView *)iconImageView;
@end

@interface SBMediaController : NSObject
+ (id)sharedInstance;
- (BOOL)isPlaying;
- (NSDictionary *)_nowPlayingInfo;
- (SBApplication *)nowPlayingApplication;
@end

@interface SBNowPlayingBarMediaControlsView : UIView {
	BOOL _isPlaying;
}
@end

@interface SBNowPlayingBarView : UIView
- (SBIconView *)nowPlayingIconView;
@end



%hook SBNowPlayingBarMediaControlsView

- (void)setTrackString:(NSString *)_title {
	BOOL isPlaying = MSHookIvar<BOOL>(self, "_isPlaying");
	
	if (_title.length == 0 && isPlaying == NO) {
		[iPodArtwork release];
		iPodArtwork = nil;
		
		[nowPlayingArtwork release];
		nowPlayingArtwork = nil;
	}
	
	%orig;
}

%end


%hook SBNowPlayingBarView

- (void)layoutSubviews {
	[nowPlayingView removeFromSuperview];
	
	%orig;
	
	CGImageRef image = NULL;
	if (nowPlayingArtwork) {
		image = LICreateIconForImage(nowPlayingArtwork.CGImage, DEFAULT_AA_VARIANT, 0);
	} else if (iPodArtwork) {
		image = LICreateIconForImage(iPodArtwork.CGImage, DEFAULT_AA_VARIANT, 0);
	}
	
	if (image != NULL) {
		UIImage *temp = [[UIImage alloc] initWithCGImage:image];
		[nowPlayingView setImage:temp];
		[temp release];
		CGImageRelease(image);
		image = NULL;
		SBIconImageContainerView *containerView = MSHookIvar<SBIconImageContainerView *>(self.nowPlayingIconView, "_iconImageContainer");
		[containerView insertSubview:nowPlayingView aboveSubview:[[self nowPlayingIconView] iconImageView]];
	}
}

%new(v@:)
- (void)aaosSetiPodNowPlaying {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	MPMusicPlayerController *iPodController = [MPMusicPlayerController iPodMusicPlayer];
	if (iPodController == nil) {
		[pool release];
		return;
	}
	MPMediaItem *nowPlayingItem = [iPodController nowPlayingItem];
	if (nowPlayingItem == nil) {
		[pool release];
		return;
	}
	
	MPMediaItemArtwork *coverArt = [nowPlayingItem valueForProperty:MPMediaItemPropertyArtwork];
	if (coverArt) {
		[iPodArtwork release];
		iPodArtwork = nil;
		iPodArtwork = [[coverArt imageWithSize:CGSizeMake(DEFAULT_AA_SIZE,DEFAULT_AA_SIZE)] copy];
	}
	
	[self setNeedsLayout];
	
	[pool release];
}

%new(v@:)
- (void)aaosSetGlobalNowPlaying {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	SBMediaController *mediaController = [objc_getClass("SBMediaController") sharedInstance];
	
	if ([mediaController isPlaying]) {
		if ([[[mediaController nowPlayingApplication] displayIdentifier] isEqualToString:MOBILEIPOD_ID]) {
			[nowPlayingArtwork release];
			nowPlayingArtwork = nil;
			
			[pool release];
			return;
		}
		
		[iPodArtwork release];
		iPodArtwork = nil;
		
		NSData *tempData = [[mediaController _nowPlayingInfo] objectForKey:@"artworkData"];
		
		if (tempData) {
			[nowPlayingArtwork release];
			nowPlayingArtwork = nil;
			nowPlayingArtwork = [[UIImage alloc] initWithData:tempData];
		}
	}
	
	[self setNeedsLayout];
	
	[pool release];
}

%new(v@:@@)
- (void)aaosiPodNowPlayingItemChanged:(NSNotification *)notification {
	[self performSelector:@selector(aaosSetiPodNowPlaying)];
}

%new(v@:@@)
- (void)aaosiPodPlaybackStateChanged:(NSNotification *)notification {
	NSInteger playbackState = [[[notification userInfo] objectForKey:@"MPMusicPlayerControllerPlaybackStateKey"] intValue];
	
	if (playbackState == MPMusicPlaybackStatePlaying) {
		[self performSelector:@selector(aaosSetiPodNowPlaying)];
	}
}

%new(v@:@@)
- (void)aaosGlobalNowPlayingItemChanged:(NSNotification *)notification {
	[self performSelector:@selector(aaosSetGlobalNowPlaying)];
}

- (id)initWithFrame:(struct CGRect)frame {
	id rtn = %orig;
	
	nowPlayingView = [[UIImageView alloc] initWithFrame:CGRectMake(0,-2,DEFAULT_AA_SIZE-1,DEFAULT_AA_SIZE+2)];
	//nowPlayingView.contentMode = UIViewContentModeScaleAspectFit;
	//nowPlayingView.backgroundColor = [UIColor blackColor];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(aaosiPodPlaybackStateChanged:) 
												 name:MPMusicPlayerControllerPlaybackStateDidChangeNotification 
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(aaosiPodNowPlayingItemChanged:) 
												 name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification 
											   object:nil];
	[[MPMusicPlayerController iPodMusicPlayer] beginGeneratingPlaybackNotifications];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(aaosGlobalNowPlayingItemChanged:) 
												 name:@"SBMediaNowPlayingChangedNotification" 
											   object:nil];
	
	[self performSelector:@selector(aaosSetiPodNowPlaying)];
	[self performSelector:@selector(aaosSetGlobalNowPlaying)];
	
	return rtn;
}

%end



%ctor
{
	size_t size;
	sysctlbyname("hw.machine", NULL, &size, NULL, 0);
	char *name = (char *)malloc(size);
	sysctlbyname("hw.machine", name, &size, NULL, 0);
	
	if (strstr(name, "iPhone2"))
		this_device = DeviceTypeiPhone3Gs;
	else if (strstr(name, "iPod3"))
		this_device = DeviceTypeiPodTouch3g;
	else if (strstr(name, "iPad1") || strstr(name, "iPad2"))
		this_device = DeviceTypeiPad;
	else if (strstr(name, "iPhone1"))
		this_device = DeviceTypeUnsupported;
	else if (strstr(name, "iPod1") || strstr(name, "iPod2"))
		this_device = DeviceTypeUnsupported;
	else if (strstr(name, "iPod"))			// above iPodTouch 4g
		this_device = DeviceTypeiPodTouch4g;
	else if (strstr(name, "iPhone"))		// above iPhone 4
		this_device = DeviceTypeiPhone4;
	else if (strstr(name, "iPad"))
		this_device = DeviceTypeiPad3g;
	else
		this_device = DeviceTypeUnsupported;
	
	free(name);
	
	NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
	
	if (![identifier isEqualToString:@"com.apple.springboard"]) return;
	
	%init;
}

