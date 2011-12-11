//
//  AlbumArtOnSwitcher
//  
//  
//  Copyright (c) 2011 deVbug
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



#define MOBILEIPOD_ID							@"com.apple.mobileipod"
#define DEFAULT_AA_SIZE							60


static UIImage *iPodArtwork = nil;
static UIImage *nowPlayingArtwork = nil;
static UIImageView *nowPlayingView = nil;


@interface SBApplication : NSObject
- (NSString *)displayIdentifier;
@end

@interface SBIconView : UIView
@end

@interface SBNowPlayingBarView : UIView
- (SBIconView *)nowPlayingIconView;
@end

@interface SBMediaController : NSObject
+ (id)sharedInstance;
- (BOOL)isPlaying;
- (NSDictionary *)_nowPlayingInfo;
- (SBApplication *)nowPlayingApplication;
@end


%hook SBNowPlayingBarView

- (void)layoutSubviews {
	[nowPlayingView removeFromSuperview];
	
	%orig;
	
	if (nowPlayingArtwork) {
		[nowPlayingView setImage:nowPlayingArtwork];
		[[self nowPlayingIconView] addSubview:nowPlayingView];
	} else if (iPodArtwork) {
		[nowPlayingView setImage:iPodArtwork];
		[[self nowPlayingIconView] addSubview:nowPlayingView];
	}
}

%new(v@:)
- (void)aaosSetiPodNowPlaying {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iPodArtwork release];
	iPodArtwork = nil;
	
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
	if (coverArt)
		iPodArtwork = [[coverArt imageWithSize:CGSizeMake(DEFAULT_AA_SIZE,DEFAULT_AA_SIZE)] copy];
		
	[self setNeedsLayout];
	
	[pool release];
}

%new(v@:)
- (void)aaosSetGlobalNowPlaying {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[nowPlayingArtwork release];
	nowPlayingArtwork = nil;
	
	SBMediaController *mediaController = [objc_getClass("SBMediaController") sharedInstance];
	
	if ([mediaController isPlaying]) {
		if ([[[mediaController nowPlayingApplication] displayIdentifier] isEqualToString:MOBILEIPOD_ID]) {
			[pool release];
			return;
		}
		
		NSData *tempData = [[mediaController _nowPlayingInfo] objectForKey:@"artworkData"];
		
		if (tempData)
			nowPlayingArtwork = [[UIImage alloc] initWithData:tempData];
	}
	
	[self setNeedsLayout];
	
	[pool release];
}

%new(v@:)
- (void)aaosUnsetNowPlaying {
	[iPodArtwork release];
	iPodArtwork = nil;
	
	[nowPlayingArtwork release];
	nowPlayingArtwork = nil;
	
	[self setNeedsLayout];
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
	} else if (playbackState == MPMusicPlaybackStateStopped || 
			   playbackState == MPMusicPlaybackStateInterrupted || 
			   playbackState == MPMusicPlaybackStatePaused) {
		[self performSelector:@selector(aaosUnsetNowPlaying)];
	}
}

%new(v@:@@)
- (void)aaosGlobalNowPlayingItemChanged:(NSNotification *)notification {
	[self performSelector:@selector(aaosSetGlobalNowPlaying)];
}
	
- (id)initWithFrame:(struct CGRect)frame {
	id rtn = %orig;
	
	nowPlayingView = [[UIImageView alloc] initWithFrame:CGRectMake(-1,-2,DEFAULT_AA_SIZE,DEFAULT_AA_SIZE)];
	nowPlayingView.contentMode = UIViewContentModeScaleAspectFit;
	nowPlayingView.backgroundColor = [UIColor blackColor];
	
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
	
	return rtn;
}

%end



%ctor
{
	NSString *identifier = [[NSBundle mainBundle] bundleIdentifier];
	
	if (![identifier isEqualToString:@"com.apple.springboard"]) return;
	
	%init;
}

