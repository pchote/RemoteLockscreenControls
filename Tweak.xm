/*
 * This file is part of Remote Lockscreen Controls, Copyright 2012 Paul Chote
 * It is made available to you under the terms of version 3 (or later) of the
 * GNU General Public License, as published by the Free Software Foundation.
 * If you are not familiar with the terms of the GPLV3, see the included LICENSE
 */

// Dumped from Remote.app with class-dump-z
#import "MRNowPlayingFrontScreen.h"
#import "RCiTunesPlayer.h"
#import "RCDAAPItem.h"

#import <AVFoundation/AVPlayer.h>
#import <AVFoundation/AVAudioPlayer.h>
#import <AVFoundation/AVAudioSession.h>
#import <MediaPlayer/MPNowPlayingInfoCenter.h>
#import <MediaPlayer/MPMediaItem.h>

%hook MRNowPlayingFrontScreen

// A fake audio player that reflects the state of the remote audio
AVAudioPlayer *audioPlayer;

/*
 * Hook view loading to initialize a fake audio player (required to recieve remote events)
 */
- (void)viewDidLoad
{
    %orig;

    // TODO: Make this work without an audio file.
    // For now, it expects Robot.m4r in the Remote.app bundle
    NSURL *dummyAudio = [[NSBundle mainBundle] URLForResource:@"Robot" withExtension:@"m4r"];
    NSError *error;

    audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:dummyAudio error:&error];
    [audioPlayer setNumberOfLoops:-1];
 
    if (error)
    {
        NSLog(@"%@", [error localizedDescription]);
        return;
    }

    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
    [audioPlayer prepareToPlay];
}

/*
 * Hook track info update to update the "now playing info" dict
 */
-(void)updateTrackInfo
{
    %orig;
    RCDAAPItem *song = [[self remote] currentSong];

    NSMutableDictionary *nowPlayingInfo = [[[NSMutableDictionary alloc] initWithObjectsAndKeys:
        [song name], MPMediaItemPropertyTitle,
        [song songalbum], MPMediaItemPropertyAlbumTitle,
        [song songalbumartist], MPMediaItemPropertyArtist,
    nil] autorelease];

    UIImage *albumImage = [[self albumArt] image];
    if (albumImage)
    {
        MPMediaItemArtwork *albumArtwork = [[[MPMediaItemArtwork alloc] initWithImage:albumImage] autorelease];
        [nowPlayingInfo setObject:albumArtwork forKey:MPMediaItemPropertyArtwork];
    }

    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nowPlayingInfo];
}

/*
 * Hook view appearing to enable remote control events and become first responder
 */
- (void)viewDidAppear:(BOOL)animated
{
    %orig;

    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

/*
 * Hook view disappearing to disable remote control events and resign first responder
 * TODO: Hook up the background audio API so we can still take events in the background?
 */
- (void)viewWillDisappear:(BOOL)animated
{
    [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    [self resignFirstResponder];

    %orig;
}

/*
 * Hook the play/pause button press action to toggle our fake audio player
 * (the system play/pause state is based off the state of the fake player)
 */
-(void)onPlay:(id)play
{
    if (![[self remote] isPlaying])
        [audioPlayer play];
    else
        [audioPlayer pause];

    %orig;
}

/*
 * Map remote control -> button press events
 * TODO: Hook volume controls?
 * Not sure if stealing the system volume control for a remote stream is a good idea
 */
-(void)remoteControlReceivedWithEvent:(UIEvent *)receivedEvent
{
    if (receivedEvent.type == UIEventTypeRemoteControl)
    {
        switch (receivedEvent.subtype)
        {
            case UIEventSubtypeRemoteControlTogglePlayPause:
                [self onPlay:nil];
                break;
            case UIEventSubtypeRemoteControlPreviousTrack:
                [self onPrev:nil];
                break;
            case UIEventSubtypeRemoteControlNextTrack:
                [self onNext:nil];
                break;
            default:
                break;
        }
    }
}

/*
 * Allow first responder so we can receive remote control events
 */
-(BOOL)canBecomeFirstResponder
{
    return YES;
}

%end