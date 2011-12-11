
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>



static UIImage *iPodArtwork = nil;
static UIImage *nowPlayingArtwork = nil;
static UIImageView *nowPlayingView = nil;


@interface SBIcon : NSObject
@end

@interface SBApplication : NSObject
- (NSString *)displayIdentifier;
@end

@interface SBApplicationIcon : SBIcon
- (SBApplication *)application;
@end

@interface SBIconView : UIView
- (SBIcon *)icon;
@end

@interface SBNowPlayingBarView : UIView
- (SBIconView *)nowPlayingIconView;
@end

@interface SBMediaController : NSObject
+ (id)sharedInstance;
- (BOOL)isPlaying;
- (NSDictionary *)_nowPlayingInfo;
- (id)nowPlayingApplication;
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
		iPodArtwork = [[coverArt imageWithSize:CGSizeMake(60,60)] copy];
		
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
		if ([[(SBApplication *)[mediaController nowPlayingApplication] displayIdentifier] isEqualToString:@"com.apple.mobileipod"]) {
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
	
	nowPlayingView = [[UIImageView alloc] initWithFrame:CGRectMake(-1,-2,60,60)];
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

