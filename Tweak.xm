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
AVAudioPlayer *audioPlayer = nil;

// A dictionary of song info to display on the lock screen and media tray
NSMutableDictionary *nowPlayingDict = nil;

/*
 * Hook view loading to initialize a fake audio player (required to recieve remote events)
 */
- (void)viewDidLoad
{
    %orig;

    if (!nowPlayingDict)
        nowPlayingDict = [[NSMutableDictionary alloc] init];

    if (!audioPlayer)
    {
        // A system sound to run indefinitely at zero volume while the remote song is playing
        NSURL *dummyAudio = [NSURL URLWithString:@"/System/Library/CoreServices/SpringBoard.app/ring.m4r"];
        NSError *error;
        audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:dummyAudio error:&error];
        if (error)
        {
            NSLog(@"%@", [error localizedDescription]);
            return;
        }

        [audioPlayer setNumberOfLoops:-1];
        [audioPlayer setVolume:0];

        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
        [[AVAudioSession sharedInstance] setActive:YES error:nil];
        [audioPlayer prepareToPlay];
        [audioPlayer pause];
    }
}

/*
 * Hook track info update to update the "now playing info" dict
 */
-(void)updateTrackInfo
{
    %orig;

    RCDAAPItem *song = [[self remote] currentSong];
    if ([song name])
        [nowPlayingDict setObject:[song name] forKey:MPMediaItemPropertyTitle];
    if ([song songalbum])
        [nowPlayingDict setObject:[song songalbum] forKey:MPMediaItemPropertyAlbumTitle];
    if ([song songartist])
        [nowPlayingDict setObject:[song songartist] forKey:MPMediaItemPropertyArtist];
    if ([song songalbumartist])
        [nowPlayingDict setObject:[song songalbumartist] forKey:MPMediaItemPropertyAlbumArtist];

    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nowPlayingDict];
}

/*
 * Hook album art update to update the "now playing info" dict
 */
-(void)updateArt
{
    %orig;

    UIImage *albumImage = [[self albumArt] image];
    if (!albumImage)
        return;

    MPMediaItemArtwork *albumArtwork = [[[MPMediaItemArtwork alloc] initWithImage:albumImage] autorelease];
    [nowPlayingDict setObject:albumArtwork forKey:MPMediaItemPropertyArtwork];

    [[MPNowPlayingInfoCenter defaultCenter] setNowPlayingInfo:nowPlayingDict];
}

/*
 * Hook view appearing to enable remote control events and become first responder
 */
- (void)viewDidAppear:(BOOL)animated
{
    %orig(animated);

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

    %orig(animated);
}

/*
 * Hook the button state change to toggle the fake player
 * (the system play/pause state is based off the state of the fake player)
 */
-(void)setPlayButtonIsPlaying:(BOOL)playing
{
    %orig(playing);

    if (playing)
        [audioPlayer play];
    else
        [audioPlayer pause];
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