// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
// #docregion imports
import 'package:interactive_media_ads/interactive_media_ads.dart';
import 'package:video_player/video_player.dart';
// #enddocregion imports

/// Entry point for integration tests that require espresso.
@pragma('vm:entry-point')
void integrationTestMain() {
  enableFlutterDriverExtension();
  main();
}

void main() {
  runApp(const MaterialApp(home: AdExampleWidget()));
}

// #docregion example_widget
/// Example widget displaying an Ad before a video.
class AdExampleWidget extends StatefulWidget {
  /// Constructs an [AdExampleWidget].
  const AdExampleWidget({super.key});

  @override
  State<AdExampleWidget> createState() => _AdExampleWidgetState();
}

class _AdExampleWidgetState extends State<AdExampleWidget>
    with WidgetsBindingObserver {
  // IMA sample tag for a single skippable inline video ad. See more IMA sample
  // tags at https://developers.google.com/interactive-media-ads/docs/sdks/html5/client-side/tags
  static const String _adTagUrl =
      'https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_preroll_skippable&sz=640x480&ciu_szs=300x250%2C728x90&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator=';

  // The AdsLoader instance exposes the request ads method.
  late final AdsLoader _adsLoader;

  // AdsManager exposes methods to control ad playback and listen to ad events.
  AdsManager? _adsManager;

  // #enddocregion example_widget
  // Last state received in `didChangeAppLifecycleState`.
  AppLifecycleState _lastLifecycleState = AppLifecycleState.resumed;

  // #docregion example_widget
  // Whether the widget should be displaying the content video. The content
  // player is hidden while Ads are playing.
  bool _shouldShowContentVideo = true;

  // Controls the content video player.
  late final VideoPlayerController _contentVideoController;
  // #enddocregion example_widget

  // #docregion ad_and_content_players
  late final AdDisplayContainer _adDisplayContainer = AdDisplayContainer(
    onContainerAdded: (AdDisplayContainer container) {
      // Ads can't be requested until the `AdDisplayContainer` has been added to
      // the native View hierarchy.
      _requestAds(container);
    },
  );

  @override
  void initState() {
    super.initState();
    // #enddocregion ad_and_content_players
    // Adds this instance as an observer for `AppLifecycleState` changes.
    WidgetsBinding.instance.addObserver(this);

    // #docregion ad_and_content_players
    _contentVideoController = VideoPlayerController.networkUrl(
      Uri.parse(
        'https://storage.googleapis.com/gvabox/media/samples/stock.mp4',
      ),
    )
      ..addListener(() {
        if (_contentVideoController.value.isCompleted) {
          _adsLoader.contentComplete();
        }
        setState(() {});
      })
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
  }
  // #enddocregion ad_and_content_players

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_shouldShowContentVideo) {
          _adsManager?.resume();
        }
      case AppLifecycleState.inactive:
        // Pausing the Ad video player on Android can only be done in this state
        // because it corresponds to `Activity.onPause`. This state is also
        // triggered before resume, so this will only pause the Ad if the app is
        // in the process of being sent to the background.
        if (!_shouldShowContentVideo &&
            _lastLifecycleState == AppLifecycleState.resumed) {
          _adsManager?.pause();
        }
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
    }
    _lastLifecycleState = state;
  }

  // #docregion request_ads
  Future<void> _requestAds(AdDisplayContainer container) {
    _adsLoader = AdsLoader(
      container: container,
      onAdsLoaded: (OnAdsLoadedData data) {
        final AdsManager manager = data.manager;
        _adsManager = data.manager;

        manager.setAdsManagerDelegate(AdsManagerDelegate(
          onAdEvent: (AdEvent event) {
            debugPrint('OnAdEvent: ${event.type} => ${event.adData}');
            switch (event.type) {
              case AdEventType.loaded:
                manager.start();
              case AdEventType.contentPauseRequested:
                _pauseContent();
              case AdEventType.contentResumeRequested:
                _resumeContent();
              case AdEventType.allAdsCompleted:
                manager.destroy();
                _adsManager = null;
              case AdEventType.clicked:
              case AdEventType.complete:
              case _:
            }
          },
          onAdErrorEvent: (AdErrorEvent event) {
            debugPrint('AdErrorEvent: ${event.error.message}');
            _resumeContent();
          },
        ));

        manager.init();
      },
      onAdsLoadError: (AdsLoadErrorData data) {
        debugPrint('OnAdsLoadError: ${data.error.message}');
        _resumeContent();
      },
    );

    return _adsLoader.requestAds(AdsRequest(adTagUrl: _adTagUrl));
  }

  Future<void> _resumeContent() {
    setState(() {
      _shouldShowContentVideo = true;
    });
    return _contentVideoController.play();
  }

  Future<void> _pauseContent() {
    setState(() {
      _shouldShowContentVideo = false;
    });
    return _contentVideoController.pause();
  }
  // #enddocregion request_ads

  // #docregion dispose
  @override
  void dispose() {
    super.dispose();
    _contentVideoController.dispose();
    _adsManager?.destroy();
    // #enddocregion dispose
    WidgetsBinding.instance.removeObserver(this);
    // #docregion dispose
  }
  // #enddocregion dispose

  // #docregion example_widget
  // #docregion widget_build
  @override
  Widget build(BuildContext context) {
    // #enddocregion example_widget
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          child: !_contentVideoController.value.isInitialized
              ? Container()
              : AspectRatio(
                  aspectRatio: _contentVideoController.value.aspectRatio,
                  child: Stack(
                    children: <Widget>[
                      // The display container must be on screen before any Ads can be
                      // loaded and can't be removed between ads. This handles clicks for
                      // ads.
                      _adDisplayContainer,
                      if (_shouldShowContentVideo)
                        VideoPlayer(_contentVideoController)
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton:
          _contentVideoController.value.isInitialized && _shouldShowContentVideo
              ? FloatingActionButton(
                  onPressed: () {
                    setState(() {
                      _contentVideoController.value.isPlaying
                          ? _contentVideoController.pause()
                          : _contentVideoController.play();
                    });
                  },
                  child: Icon(
                    _contentVideoController.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                )
              : null,
    );
    // #docregion example_widget
  }
  // #enddocregion widget_build
}
// #enddocregion example_widget
