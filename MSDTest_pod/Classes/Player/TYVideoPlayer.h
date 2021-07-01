//
//  TYVideoPlayer.h
//  Project
//
//  Created by Hoard on 03/03/2019.
//  Copyright © 2019 com.tianyu.mobiledev. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVKit/AVKit.h>

@class TYVideoPlayer;

@protocol TYVideoPlayerDelegate <NSObject>

@optional
/// AudioSession 设置失败, 不一定播放不成功
- (void)videoPlayerDidAudioSessionSettingError:(TYVideoPlayer * _Nonnull)player error:(NSError *_Nonnull)error;
/// 播放失败
- (void)videoPlayerDidFailed:(TYVideoPlayer *_Nonnull)player;
/// 准备播放
- (void)videoPlayerReadyToPlay:(TYVideoPlayer *_Nonnull)player;
/// 播放结束
- (void)videoPlayerDidFinished:(TYVideoPlayer *_Nonnull)player;
/// 播放被暂停
- (void)videoPlayerDidPaused:(TYVideoPlayer *_Nonnull)player;

@end

NS_ASSUME_NONNULL_BEGIN

@interface TYVideoPlayer : UIView

@property (nonatomic, weak) id <TYVideoPlayerDelegate> delegate;

/// 视频地址
@property (nonatomic, strong) NSURL *videoURL;
/// 填充模式 默认为AVLayerVideoGravityResizeAspectFill
@property (nonatomic, assign) AVLayerVideoGravity videoGravity;
/// 是否正在播放
@property (nonatomic, assign, readonly) BOOL isPlaying;
/// 是否循环播放,默认为True
@property (nonatomic, assign) BOOL repeat;
/// asset资源
@property (nonatomic, strong) AVURLAsset *UrlAsset;

@property (nonatomic, assign) BOOL unmuted;

/**
 播放
 */
- (void)play;

/**
 暂停
 */
- (void)pause;

/**
 结束
 */
- (void)stop;


/**
 获取视频宽高比(准备播放后获取)

 @return 宽高比
 */
- (CGFloat)getVideoWHRate;

/**
 当前播放的时间

 @return 当前播放的时间
 */
- (double)getCurrentPlayingTime;

/**
 总的视频时间(准备播放后获取)

 @return 总的视频时间
 */
- (double)getTotalPlayingTime;


/**
 获取视频特定时间截图

 @param videoTime 具体时间
 @return 该时间帧的截图
 */
- (UIImage *)getThumbnailImageFromVideo:(long long)videoTime;


/**
 跳到指定时间播放

 */
- (void)seekToTime:(long long)time completionHandler:(nullable void (^)(BOOL finished))completionHandler;

/**
 实时缓冲
 
 @param completionHandler 实时缓冲回调
 */
- (void)getLoadedTimeRanges:(nullable void (^)(long long start, long long duration))completionHandler;

@end

NS_ASSUME_NONNULL_END
