
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>



static UIImage *iPodArtwork = nil;
static UIImage *nowPlayingArtwork = nil;
static UIImageView *nowPlayingView = nil;


@interface SBIcon : NSObject
- (NSString *)displayName;
@end

@interface SBApplication : NSObject
- (NSString *)displayIdentifier;
@end

@interface SBApplicationIcon : SBIcon
- (SBApplication *)application;
@end

@interface SBIconView : UIView
- (SBIcon *)icon;
- (int)location;
- (UIImageView *)iconImageView;
- (void)setDisplayedIconImage:(id)fp8;
@end

@interface SBNowPlayingBarView : UIView
- (void)layoutSubviews;
- (void)_layoutForiPhone;
- (void)_layoutForiPad;
- (void)setNowPlayingIconView:(id)fp8;
- (SBIconView *)nowPlayingIconView;
@end

@interface SBMediaController : NSObject
+ (id)sharedInstance;
- (BOOL)isPlaying;
- (NSDictionary *)_nowPlayingInfo;
- (id)nowPlayingArtist;
- (id)nowPlayingTitle;
- (id)nowPlayingAlbum;
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
	//NSLog(@"[AAOS] aaosSetiPodNowPlaying");
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[iPodArtwork release];
	iPodArtwork = nil;
	
	MPMusicPlayerController *iPodController = [MPMusicPlayerController iPodMusicPlayer];
	if (iPodController == nil) {
		//NSLog(@"[AAOS] iPodController is nil");
		[pool release];
		return;
	}
	MPMediaItem *nowPlayingItem = [iPodController nowPlayingItem];
	if (nowPlayingItem == nil) {
		//NSLog(@"[AAOS] nowPlayingItem is nil");
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
	//NSLog(@"[AAOS] aaosSetiPodNowPlaying");
	
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
	//NSLog(@"[AAOS] aaosUnsetNowPlaying");
	
	[iPodArtwork release];
	iPodArtwork = nil;
	
	[nowPlayingArtwork release];
	nowPlayingArtwork = nil;
	
	[self setNeedsLayout];
}

%new(v@:@@)
- (void)aaosiPodNowPlayingItemChanged:(NSNotification *)notification {
	//NSString *persistentID = [[notification userInfo] objectForKey:@"MPMusicPlayerControllerNowPlayingItemPersistentIDKey"];
	//NSLog(@"[AAOS] iPod PlayingItemChanged :: %@", persistentID);
	
	[self performSelector:@selector(aaosSetiPodNowPlaying)];
}
	
%new(v@:@@)
- (void)aaosiPodPlaybackStateChanged:(NSNotification *)notification {
	NSInteger playbackState = [[[notification userInfo] objectForKey:@"MPMusicPlayerControllerPlaybackStateKey"] intValue];
	
	if (playbackState == MPMusicPlaybackStatePlaying) {
		//NSLog(@"[AAOS] iPod PlaybackStateChanged to playing");
		
		[self performSelector:@selector(aaosSetiPodNowPlaying)];
	} else if (playbackState == MPMusicPlaybackStateStopped || 
			   playbackState == MPMusicPlaybackStateInterrupted || 
			   playbackState == MPMusicPlaybackStatePaused) {
		//NSLog(@"[AAOS] iPod PlaybackStateChanged to stop");
		
		[self performSelector:@selector(aaosUnsetNowPlaying)];
	}
}

%new(v@:@@)
- (void)aaosGlobalNowPlayingItemChanged:(NSNotification *)notification {
	//NSLog(@"[AAOS] global PlayingItemChanged");
	
	[self performSelector:@selector(aaosSetGlobalNowPlaying)];
}

/*%new(v@:@@)
- (void)aaosGlobalPlaybackStateChanged:(NSNotification *)notification {
	//NSLog(@"[AAOS] aaosGlobalPlaybackStateChanged %@", notification);
	
	NSInteger playbackState = [[[notification userInfo] objectForKey:@"kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey"] intValue];
	
	if (playbackState == 1) {
		//
	} else { // playbackState == 0
		[self performSelector:@selector(aaosUnsetNowPlaying)];
	}
}*/
	
- (id)initWithFrame:(struct CGRect)fp8 {
	id rtn = %orig;
	
	nowPlayingView = [[UIImageView alloc] init];
	nowPlayingView.frame = CGRectMake(-1,-2,60,60);
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
	
	/*[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(aaosGlobalPlaybackStateChanged:) 
												 name:@"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification" 
											   object:nil];*/
	// kMRMediaRemoteNowPlayingInfoDidChangeNotification
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

