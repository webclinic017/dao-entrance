import 'package:asyou_app/utils/screen/size_extension.dart';
import 'package:flutter/material.dart';

import 'package:matrix/matrix.dart' as link;

import '../../components/user_avatar.dart';
import '../../store/theme.dart';
import '../../utils/time.dart';

class Msg extends StatefulWidget {
  final link.Event event;
  final link.Event? preEvent;
  final link.Client client;

  const Msg({Key? key, required this.event, required this.client, this.preEvent}) : super(key: key);

  @override
  State<Msg> createState() => _MsgState();
}

class _MsgState extends State<Msg> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var event = widget.event;
    var showAvatar = true;
    var showDate = false;
    if (widget.preEvent != null) {
      link.Event preEvent = widget.preEvent!;
      if (event.originServerTs.millisecondsSinceEpoch - preEvent.originServerTs.millisecondsSinceEpoch < 240000 &&
          event.senderId == preEvent.senderId) {
        showAvatar = false;
      }
      if ("${event.originServerTs.year}-${event.originServerTs.month}-${event.originServerTs.day}" !=
          "${preEvent.originServerTs.year}-${preEvent.originServerTs.month}-${preEvent.originServerTs.day}") {
        showDate = true;
      }
    }
    return Row(
      key: Key(event.eventId),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 20.w),
        if (showAvatar)
          Column(
            children: [
              SizedBox(height: 10.w),
              if (showAvatar && showDate) SizedBox(height: 40.w, width: 40.w),
              UserAvatar(
                key: Key("user_${event.eventId}"),
                event.senderId,
                true,
                40.w,
              ),
            ],
          ),
        if (!showAvatar) SizedBox(width: 40.w),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showAvatar) SizedBox(height: 10.w),
              if (showAvatar && showDate) buildDayTag(event),
              if (showAvatar)
                RichText(
                  text: TextSpan(
                    text: event.senderId == widget.client.userID ? "我" : event.senderId,
                    style: TextStyle(
                      color: ConstTheme.centerChannelColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15.w,
                    ),
                    children: [
                      TextSpan(
                        text: "  ${getTime(event.originServerTs)}",
                        style: TextStyle(
                          color: ConstTheme.centerChannelColor.withAlpha(155),
                          fontWeight: FontWeight.w400,
                          fontSize: 12.w,
                        ),
                      )
                    ],
                  ),
                ),
              if (showAvatar) SizedBox(height: 5.w),
              Text(
                event.body,
                style: TextStyle(
                  fontSize: 14.w,
                  color: ConstTheme.centerChannelColor,
                ),
              ),
              SizedBox(height: 5.w),
              // (detailMessages[index].srcImage != null)
              //     ? ClipRRect(
              //         borderRadius:
              //             BorderRadius.circular(10.w),
              //         child: Image.network(
              //           detailMessages[index].srcImage!,
              //           width: MediaQuery.of(context)
              //                   .size
              //                   .width *
              //               0.7,
              //         ),
              //       )
              //     : const SizedBox(),
            ],
          ),
        ),
      ],
    );
  }

  buildDayTag(event) {
    return Row(
      children: [
        SizedBox(width: 20.w),
        Expanded(
          child: SizedBox(
            width: double.maxFinite,
            height: 40.w,
            child: Stack(
              alignment: AlignmentDirectional.center,
              children: [
                Container(
                  height: 1,
                  color: ConstTheme.centerChannelColor.withOpacity(0.08),
                ),
                Positioned(
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 5.w, horizontal: 10.w),
                    decoration: BoxDecoration(color: ConstTheme.centerChannelBg),
                    child: Text(
                      getDay(event.originServerTs),
                      style: TextStyle(color: ConstTheme.centerChannelColor, fontSize: 14.w),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
        SizedBox(width: 90.w),
      ],
    );
  }
}