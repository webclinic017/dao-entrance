// Copyright 2023 FluffyChat.
// This file is part of FluffyChat

// Licensed under the AGPL;
//
// https://gitlab.com/famedly/fluffychat
//

import 'package:asyou_app/domain/utils/screen/screen.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';

import 'package:asyou_app/infra/components/app_bar.dart';
import 'package:asyou_app/infra/components/mxc_image.dart';
import 'package:asyou_app/application/store/theme.dart';
import 'package:asyou_app/domain/utils/platform_infos.dart';
import 'image_viewer.dart';

class ImageViewerView extends StatelessWidget {
  final ImageViewerController controller;

  const ImageViewerView(this.controller, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final constTheme = Theme.of(context).extension<ExtColors>()!;
    return Scaffold(
      backgroundColor: constTheme.centerChannelBg,
      extendBodyBehindAppBar: true,
      appBar: LocalAppBar(
        backgroundColor: constTheme.sidebarHeaderBg.withOpacity(0.6),
        leading: Padding(
          padding: EdgeInsets.only(left: 10.w),
          child: IconButton(
            icon: const Icon(Icons.close),
            onPressed: Navigator.of(context).pop,
            color: Colors.white,
            tooltip: L10n.of(context)!.close,
          ),
        ),
        tools: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.reply_outlined),
              onPressed: controller.forwardAction,
              color: Colors.white,
              tooltip: L10n.of(context)!.share,
            ),
            if (!PlatformInfos.isIOS)
              IconButton(
                icon: const Icon(Icons.download_outlined),
                onPressed: () => controller.saveFileAction(context),
                color: Colors.white,
                tooltip: L10n.of(context)!.downloadFile,
              ),
            if (PlatformInfos.isMobile)
              // Use builder context to correctly position the share dialog on iPad
              Builder(
                builder: (context) => IconButton(
                  onPressed: () => controller.shareFileAction(context),
                  tooltip: L10n.of(context)!.share,
                  color: Colors.white,
                  icon: Icon(Icons.adaptive.share_outlined),
                ),
              )
          ],
        ),
      ),
      body: InteractiveViewer(
        minScale: 1.0,
        maxScale: 10.0,
        onInteractionEnd: controller.onInteractionEnds,
        child: Center(
          child: Hero(
            tag: controller.widget.event.eventId,
            child: MxcImage(
              event: controller.widget.event,
              fit: BoxFit.contain,
              isThumbnail: false,
              animated: true,
            ),
          ),
        ),
      ),
    );
  }
}
