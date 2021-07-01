//
//  TYVideoPlayer.m
//  Project
//
//  Created by Hoard on 03/03/2019.
//  Copyright © 2019 com.tianyu.mobiledev. All rights reserved.
//

#import "TYVideoPlayer.h"

#define main_async(block)       \
if ([NSThread isMainThread]) {  \
block();                    \
}                               \
else {                          \
dispatch_async(dispatch_get_main_queue(), (block)); \
}

@interface TYVideoPlayer ()

@property (nonatomic, strong) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, copy) void (^completionHandler)(long long, long long);

@end

@implementation TYVideoPlayer

#pragma mark - LifeCycle
- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self commonInit];
    }
    return self;
}

- (void)dealloc {
    
    [_player pause];
    
    [self resetPlayerIfNecessary];
}

- (void)commonInit {
    NSError *error;
    if (@available(iOS 10.0, *)) {
        [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryAmbient mode:AVAudioSessionModeDefault options:AVAudioSessionCategoryOptionMixWithOthers error:&error];
    } else {
        [AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryAmbient error:&error];
    }
    
    if (error) {
        if ([self.delegate respondsToSelector:@selector(videoPlayerDidAudioSessionSettingError:error:)]) {
            [self.delegate videoPlayerDidAudioSessionSettingError:self error:error];
        }
    }
    
    NSError *activeError;
    [AVAudioSession.sharedInstance setActive:true withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&activeError];
    
    if (activeError) {
        if ([self.delegate respondsToSelector:@selector(videoPlayerDidAudioSessionSettingError:error:)]) {
            [self.delegate videoPlayerDidAudioSessionSettingError:self error:activeError];
        }
    }
    
    _videoGravity = AVLayerVideoGravityResizeAspectFill;
    _repeat = true;
    
}

- (void)setUrlAsset:(AVURLAsset *)UrlAsset {
    
    [self resetPlayerIfNecessary];
    _UrlAsset = UrlAsset;
    [self configPlayer];
}

- (void)setVideoURL:(NSURL *)videoURL {
    _videoURL = videoURL;
    
    [self resetPlayerIfNecessary];
    
    [self configPlayer];
}

- (void)setUnmuted:(BOOL)unmuted {
    _unmuted = unmuted;
    if (unmuted) {
        self.player.volume = 0;
    } else {
        self.player.volume = 1;
    }
}

- (void)resetPlayerIfNecessary {
    if (_playerItem) {
        [self removePlayerItemObservers:_playerItem];
    }
    _playerItem = nil;
    
    if (_playerLayer) {
        [_playerLayer removeFromSuperlayer];
    }
    _playerLayer = nil;
    
    if (_player) {
         [_player replaceCurrentItemWithPlayerItem:nil];
    }
    _player = nil;
    _UrlAsset = nil;
    
}

- (void)configPlayer {
    if (!_UrlAsset) {
        _UrlAsset = [[AVURLAsset alloc] initWithURL:_videoURL options:nil];
    }
    _playerItem = [AVPlayerItem playerItemWithAsset:_UrlAsset];
    if (@available(iOS 10.0, *)) {
        _playerItem.preferredForwardBufferDuration = 10.0;
    }
    
    if (!_playerItem) {
        if ([_delegate respondsToSelector:@selector(videoPlayerDidFailed:)]) {
            [_delegate videoPlayerDidFailed:self];
        }
        return;
    }
    
    [self addPlayerItemObservers:_playerItem];
    
    _player = [AVPlayer playerWithPlayerItem:_playerItem];
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    _playerLayer.videoGravity = _videoGravity;
    _playerLayer.frame = self.layer.bounds;
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
    
    [self.layer insertSublayer:_playerLayer atIndex:0];
}

- (void)removePlayerItemObservers:(AVPlayerItem *)item {
    main_async(^{
        @try {
            [item cancelPendingSeeks];
            [item removeObserver:self forKeyPath:@"status"];
            [item removeObserver:self forKeyPath:@"loadedTimeRanges"];
            [NSNotificationCenter.defaultCenter removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
            [NSNotificationCenter.defaultCenter removeObserver:self name:AVAudioSessionRouteChangeNotification object:nil];
            [NSNotificationCenter.defaultCenter removeObserver:self name:AVAudioSessionInterruptionNotification object:nil];
        } @catch (NSException *exp) {
            NSLog(@"%@", exp);
        }
    })
    
}

- (void)addPlayerItemObservers:(AVPlayerItem *)item {
    main_async(^{
        @try {
            [item addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
            [item addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
            [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(AVPlayerItemDidPlayToEndTimeNotification:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
            [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(AVAudioSessionRouteChangeNotification:) name:AVAudioSessionRouteChangeNotification object:nil];
            [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(AVAudioSessionInterruptionNotification:) name:AVAudioSessionInterruptionNotification object:nil];
        } @catch (NSException *exp) {
            NSLog(@"%@", exp);
        }
    })
   
}

- (void)play {
    
    _isPlaying = true;
    [_player play];
    
}

- (void)pause {
    
    _isPlaying = false;
    [_player pause];
    
}

- (void)stop {
    
    _isPlaying = false;
    [_player pause];
    [self resetPlayerIfNecessary];
}

- (double)getCurrentPlayingTime {
    if (_player) {
        return CMTimeGetSeconds(_player.currentTime);
    }
    return 0;
}

- (double)getTotalPlayingTime {
    if (_player.currentItem) {
        return CMTimeGetSeconds(_player.currentItem.duration);
    }
    return 0;
}

- (CGFloat)getVideoWHRate {
    if (_UrlAsset) {
        CGSize size = CGSizeZero;
        for (AVAssetTrack *track in _UrlAsset.tracks) {
            if ([track.mediaType isEqualToString:AVMediaTypeVideo]) {
                size = track.naturalSize;
            }
        }
        if (size.width != 0) {
            return size.height / size.width;
        } else {
            return 0;
        }
    }
    return 0;
}

- (UIImage *)getThumbnailImageFromVideo:(long long)videoTime {
    if (_UrlAsset) {
        AVAssetImageGenerator *gen = [AVAssetImageGenerator assetImageGeneratorWithAsset:_UrlAsset];
        gen.appliesPreferredTrackTransform = true;
        gen.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
        
        NSError *error;
        struct CGImage *image = [gen copyCGImageAtTime:CMTimeMake(videoTime, 600) actualTime:NULL error:&error];
        if (!error) {
            return [[UIImage alloc] initWithCGImage:image];
        } else {
            return nil;
        }
        
    } else {
        return nil;
    }
}

- (void)seekToTime:(long long)time completionHandler:(nullable void (^)(BOOL))completionHandler {
    if (_player) {
        AVPlayerItem *item = _player.currentItem;
        if (item) {
            [item  cancelPendingSeeks];
            CMTime cmtime = CMTimeMakeWithSeconds(time, 1);
            if (CMTIME_IS_INVALID(cmtime) || item.status != AVPlayerItemStatusReadyToPlay) {
                if (completionHandler) {
                    completionHandler(false);
                };
            } else {
                [_player seekToTime:cmtime toleranceBefore:CMTimeMake(1, 1) toleranceAfter:CMTimeMake(1, 1) completionHandler:^(BOOL finished) {
                    if (completionHandler) {
                        completionHandler(finished);
                    }
                }];
            }
        } else {
            if (completionHandler) {
                completionHandler(false);
            };
        }
    } else {
        if (completionHandler) {
            completionHandler(false);
        };
    }
}

- (void)getLoadedTimeRanges:(void (^)(long long, long long))completionHandler {
    self.completionHandler = completionHandler;
}

#pragma makr - AVPlayerItemDidPlayToEndTimeNotification
- (void)AVPlayerItemDidPlayToEndTimeNotification:(NSNotification *)note {
    _isPlaying = false;
    if ([self.delegate respondsToSelector:@selector(videoPlayerDidFinished:)]) {
        [self.delegate videoPlayerDidFinished:self];
    }
    
    if (_repeat) {
        [self seekToTime:0.0 completionHandler:nil];
        [self play];
    }
}

#pragma makr - AVAudioSessionRouteChangeNotification
- (void)AVAudioSessionRouteChangeNotification:(NSNotification *)note {
    NSDictionary *userInfo = note.userInfo;
    if (userInfo) {
        long reason = [userInfo[AVAudioSessionRouteChangeReasonKey] longValue];
        switch (reason) {
            case kAudioSessionRouteChangeReason_OldDeviceUnavailable:
                if (_isPlaying) {
                    [_player play];
                }
                break;
                
            default:
                break;
        }
    }
}

#pragma makr - AVAudioSessionInterruptionNotification
- (void)AVAudioSessionInterruptionNotification:(NSNotification *)note {
    NSDictionary *userInfo = note.userInfo;
    AVAudioSessionInterruptionType type = [userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        [self pause];
        if ([_delegate respondsToSelector:@selector(videoPlayerDidPaused:)]) {
            [_delegate videoPlayerDidPaused:self];
        }
    } else {
        AVAudioSessionInterruptionOptions option = [userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        if (option == AVAudioSessionInterruptionOptionShouldResume) {
            [self play];
        }
    }
}

#pragma makr - KVO
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (change) {
        
        if ([keyPath isEqualToString:@"status"]) {
            if (_playerItem.status == AVPlayerItemStatusReadyToPlay) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([self.delegate respondsToSelector:@selector(videoPlayerReadyToPlay:)]) {
                        [self.delegate videoPlayerReadyToPlay:self];
                    }
                });
            } else if (_playerItem.status == AVPlayerItemStatusFailed) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([self.delegate respondsToSelector:@selector(videoPlayerDidFailed:)]) {
                        [self.delegate videoPlayerDidFailed:self];
                    }
                });
            }
        } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
            NSArray *array = _playerItem.loadedTimeRanges;
            CMTimeRange timeRange = [array.firstObject CMTimeRangeValue];
            long long start = CMTimeGetSeconds(timeRange.start);
            long long duration = CMTimeGetSeconds(timeRange.duration);
            if (_completionHandler) {
                _completionHandler(start, duration);
            }
        }
    }
}

@end
