import 'package:agora_multichannel_video/utils/appid.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:agora_rtc_engine/rtc_local_view.dart' as RtcLocalView;
import 'package:agora_rtc_engine/rtc_remote_view.dart' as RtcRemoteView;
import 'package:agora_rtc_engine/rtc_channel.dart';

class LobbyPage extends StatefulWidget {
  final String rteChannelName;
  final String rtcChannelName;

  const LobbyPage({Key key, this.rteChannelName, this.rtcChannelName})
      : super(key: key);

  @override
  _LobbyPageState createState() => _LobbyPageState();
}

class _LobbyPageState extends State<LobbyPage> {
  static final _users = <int>[];
  static final _users2 = <int>[];

  final _infoStrings = <String>[];

  bool muted = false;

  ChannelMediaOptions _options = ChannelMediaOptions.fromJson(
      {'autoSubscribeAudio': true, 'autoSubscribeVideo': true});

  RtcEngine _engine;
  RtcChannel _channel;
  RtcChannel _channel2;

  @override
  void dispose() {
    // clear users
    _users.clear();
    // destroy sdk
    _engine.leaveChannel();
    _engine.destroy();
    _channel.unpublish();
    _channel.destroy();
    _channel.leaveChannel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // initialize agora sdk
    initialize();
  }

  Future<void> initialize() async {
    _engine = await RtcEngine.create(appID);
    await _engine.enableVideo();
    await _engine.setChannelProfile(ChannelProfile.LiveBroadcasting);
    _addAgoraEventHandlers();
    await _engine.joinChannel(null, widget.rteChannelName, null, 0);

    _channel = await RtcChannel.create(widget.rtcChannelName);
    // _channel2 = await RtcChannel.create(widget.rtcChannelName);
    _addRtcChannelEventHandlers();
    await _engine.setClientRole(ClientRole.Broadcaster);
    await _channel.joinChannel(null, null, 0, ChannelMediaOptions(true, true));
    await _channel.publish();

  }

  /// Add agora event handlers
  void _addAgoraEventHandlers() {
    _engine.setEventHandler(RtcEngineEventHandler(
      error: (code) {
        setState(() {
          final info = 'onError: $code';
          _infoStrings.add(info);
        });
      },
      joinChannelSuccess: (channel, uid, elapsed) {
        setState(() {
          final info = 'onJoinChannel: $channel, uid: $uid';
          _infoStrings.add(info);
        });
      },
      leaveChannel: (stats) {
        setState(() {
          _infoStrings.add('onLeaveChannel');
          _users.clear();
        });
      },
      userJoined: (uid, elapsed) {
        setState(() {
          final info = 'userJoined: $uid';
          _infoStrings.add(info);
          _users.add(uid);
        });
      },
      userOffline: (uid, reason) {
        setState(() {
          final info = 'userOffline: $uid , reason: $reason';
          _infoStrings.add(info);
          _users.remove(uid);
        });
      },
      firstRemoteVideoFrame: (uid, width, height, elapsed) {
        setState(() {
          final info = 'firstRemoteVideoFrame: $uid';
          _infoStrings.add(info);
        });
      },
    ));
  }

  void _addRtcChannelEventHandlers() {
    _channel.setEventHandler(RtcChannelEventHandler(
      error: (code) {
        setState(() {
          _infoStrings.add('Rtc Channel onError: $code');
        });
      },
      joinChannelSuccess: (channel, uid, elapsed) {
        setState(() {
          final info = 'Rtc Channel onJoinChannel: $channel, uid: $uid';
          _infoStrings.add(info);
        });
      },
      leaveChannel: (stats) {
        setState(() {
          _infoStrings.add('Rtc Channel onLeaveChannel');
          _users2.clear();
        });
      },
      userJoined: (uid, elapsed) {
        setState(() {
          final info = 'Rtc Channel userJoined: $uid';
          _infoStrings.add(info);
          _users2.add(uid);
        });
      },
      userOffline: (uid, reason) {
        setState(() {
          final info = 'Rtc Channel userOffline: $uid , reason: $reason';
          _infoStrings.add(info);
          _users2.remove(uid);
        });
      },
    ));
  }

  /// Info panel to show logs
  Widget _panel() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.topLeft,
      child: FractionallySizedBox(
        heightFactor: 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: ListView.builder(
            reverse: true,
            itemCount: _infoStrings.length,
            itemBuilder: (BuildContext context, int index) {
              if (_infoStrings.isEmpty) {
                return null;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 3,
                  horizontal: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 2,
                          horizontal: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.yellowAccent,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          _infoStrings[index],
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    )
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lobby'),
      ),
      // backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          _viewRows(),
          _viewRtcRows(),
          _panel()
        ],
      ),
    );
  }

  /// Helper function to get list of native views
  List<Widget> _getRenderViews() {
    final List<StatefulWidget> list = [];
    list.add(RtcLocalView.SurfaceView(renderMode: VideoRenderMode.Fit,));
    return list;
  }

  /// Video view wrapper
  Widget _videoView(view) {
    return Expanded(child: Container(child: view));
  }

  /// Video view row wrapper
  Widget _expandedVideoRow(List<Widget> views) {
    final wrappedViews = views.map<Widget>(_videoView).toList();
    return Expanded(
      child: Row(
        children: wrappedViews,
      ),
    );
  }

  /// Video layout wrapper
  Widget _viewRows() {
    final views = _getRenderViews();
    switch (views.length) {
      case 1:
        return Container(
            child: Column(
          children: <Widget>[_videoView(views[0])],
        ));
      case 2:
        return Container(
            child: Column(
          children: <Widget>[
            _expandedVideoRow([views[0]]),
            _expandedVideoRow([views[1]])
          ],
        ));
      case 3:
        return Container(
            child: Column(
          children: <Widget>[
            _expandedVideoRow(views.sublist(0, 2)),
            _expandedVideoRow(views.sublist(2, 3))
          ],
        ));
      case 4:
        return Container(
            child: Column(
          children: <Widget>[
            _expandedVideoRow(views.sublist(0, 2)),
            _expandedVideoRow(views.sublist(2, 4))
          ],
        ));
      default:
    }
    return Container();
  }

  List<Widget> _getRenderRtcChannelViews() {
    final List<StatefulWidget> list = [];
    _users2.forEach(
      (int uid) => list.add(
        RtcRemoteView.SurfaceView(
          uid: uid,
          channelId: widget.rtcChannelName,
          renderMode: VideoRenderMode.FILL,
        ),
      ),
    );
    return list;
  }

  /// Video layout wrapper
  Widget _viewRtcRows() {
    final views = _getRenderRtcChannelViews();
    if (views.length > 0) {
      print("NUMBER OF VIEWS : ${views.length}");
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: views.length,
        itemBuilder: (BuildContext context, int index) {
          return Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 200,
              width: MediaQuery.of(context).size.width * 0.25,
              child: _videoView(views[index])),
          );
        },
      );
    } else {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(),
      );
    }
    // switch (views.length) {
    //   case 1:
    //     return Container(
    //         child: Column(
    //       children: <Widget>[_videoView(views[0])],
    //     ));
    //   case 2:
    //     return Container(
    //         child: Column(
    //       children: <Widget>[
    //         _expandedVideoRow([views[0]]),
    //         _expandedVideoRow([views[1]])
    //       ],
    //     ));
    //   case 3:
    //     return Container(
    //         child: Column(
    //       children: <Widget>[
    //         _expandedVideoRow(views.sublist(0, 2)),
    //         _expandedVideoRow(views.sublist(2, 3))
    //       ],
    //     ));
    //   case 4:
    //     return Container(
    //         child: Column(
    //       children: <Widget>[
    //         _expandedVideoRow(views.sublist(0, 2)),
    //         _expandedVideoRow(views.sublist(2, 4))
    //       ],
    //     ));
    //   default:
    // }
    // return Container();
  }
}
