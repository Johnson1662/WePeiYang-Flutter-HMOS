import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wepei_module/commons/network/image_cache_service.dart';
import 'package:wepei_module/commons/themes/template/wpy_theme_data.dart';
import 'package:wepei_module/commons/themes/wpy_theme.dart';
import 'package:wepei_module/commons/util/text_util.dart';
import 'package:wepei_module/commons/widgets/SpoilerMask.dart';
import 'package:wepei_module/commons/widgets/loading.dart';

/// 统一Button样式
/// 千万别改!!!!千万别改!!!改了就崩溃
class WpyPic extends StatefulWidget {
  WpyPic(
    this.imageUrl, {
    Key? key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.withHolder = true,
    this.holderHeight = 40,
    this.withCache = true,
    this.alignment = Alignment.center,
    this.reduce = false,
    this.hide = false,
  }) : super(key: key);

  final String imageUrl;
  final double? width;
  final double? height;
  final double holderHeight;
  final BoxFit fit;
  final bool withHolder;
  final bool withCache;
  final Alignment alignment;
  final bool reduce;

  final bool hide;

  static get errorPlaceHolder => Builder(builder: (context) {
        return ColoredBox(
          color: WpyTheme.of(context).get(WpyColorKey.secondaryBackgroundColor),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_sharp,
                color: WpyTheme.of(context).get(WpyColorKey.infoTextColor),
              ),
              SizedBox(height: 4),
              Center(
                child: Text('加载失败',
                    style: TextUtil.base.infoText(context).w400.sp(12)),
              ),
            ],
          ),
        );
      });

  static Future<void> clearAllCache() async {
    _WpyPicState._ohosImageCache.clear();
    _WpyPicState._ohosImageRequests.clear();
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        await ImageCacheService.instance.clearAllCache();
      }
      final cacheDir = Directory('${Directory.systemTemp.path}/libCachedImageData');
      if (await cacheDir.exists()) {
        await for (final FileSystemEntity entity in cacheDir.list()) {
          await entity.delete(recursive: true);
        }
      }
    } catch (e) {}
  }

  @override
  _WpyPicState createState() => _WpyPicState();
}

class _WpyPicState extends State<WpyPic> {
  Widget get asset {
    if (widget.imageUrl.endsWith('.svg')) {
      return SvgPicture.asset(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
      );
    } else {
      return Image.asset(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
      );
    }
  }

  Widget get network {
    if (widget.imageUrl.endsWith('.svg')) {
      return SvgPicture.network(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        placeholderBuilder: widget.withHolder ? (_) => Loading() : null,
      );
    } else {
      final imageWidget = Image.network(
        widget.imageUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: widget.withHolder
            ? (context, url, progress) {
                return Container(
                  width: widget.width ?? widget.holderHeight,
                  height: widget.height ?? widget.holderHeight,
                  color: WpyTheme.of(context).get(WpyColorKey.dislikeSecondary),
                  child: Center(
                    child: SizedBox(
                        width: widget.width == null ? 20 : widget.width! * 0.25,
                        height:
                            widget.width == null ? 20 : widget.width! * 0.25,
                        child: CircularProgressIndicator(
                          value: progress?.expectedTotalBytes != null
                              ? progress!.cumulativeBytesLoaded /
                                  progress!.expectedTotalBytes!
                              : null,
                          color: WpyTheme.of(context).primary,
                        )),
                  ),
                );
              }
            : null,
        errorBuilder: widget.withHolder
            ? (context, exception, stacktrace) {
                return WpyPic.errorPlaceHolder;
              }
            : null,
      );

      final imageBuilder = () {
        if (widget.reduce && WpyTheme.of(context).brightness == Brightness.dark)
          return ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.2),
              BlendMode.darken,
            ),
            child: imageWidget,
          );
        return imageWidget;
      };

      // xxx.jpg#tag1,tag2,tag3 or xxx.jpg
      if (!widget.imageUrl.contains('#')) {
        return imageBuilder();
      }

      final tags = widget.imageUrl.split('#')[1].split(',');
      if (tags.contains("masked")) {
        return SizedBox(
            height: widget.height,
            width: widget.width,
            child: SpoilerMaskImage(child: imageBuilder()));
      }
      return imageBuilder();
    }
  }

  Widget get cachedNetwork => SizedBox(
        width: widget.width,
        height: widget.height,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          placeholder: (context, url) => CupertinoActivityIndicator(),
          errorWidget: (context, url, error) {
            print('v_image error: $error');
            return Icon(Icons.error);
          },
          fit: widget.fit,
        ),
      );

  int? _cachePixelDimension(double? logicalValue) {
    if (logicalValue == null || !logicalValue.isFinite || logicalValue <= 0) {
      return null;
    }
    final mediaQuery = MediaQuery.maybeOf(context);
    final devicePixelRatio = mediaQuery?.devicePixelRatio ??
        // ignore: deprecated_member_use
        WidgetsBinding.instance.window.devicePixelRatio;
    return (logicalValue * devicePixelRatio).round();
  }

  static final Map<String, Uint8List> _ohosImageCache = {};
  static final Map<String, Future<Uint8List>> _ohosImageRequests = {};
  Future<Uint8List>? _ohosFuture;

  @override
  void didUpdateWidget(WpyPic oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _ohosFuture = null;
    }
  }

  Widget get _ohosNetwork => LayoutBuilder(
        builder: (context, constraints) {
          final width = widget.width ??
              (constraints.hasTightWidth ? constraints.maxWidth : null);
          final height = widget.height ??
              (constraints.hasTightHeight ? constraints.maxHeight : null);
          return _buildOhosNetwork(width, height);
        },
      );

  Widget _buildOhosNetwork(double? width, double? height) {
    final cachedBytes = _ohosImageCache[widget.imageUrl];
    if (cachedBytes != null && cachedBytes.isNotEmpty) {
      return _buildOhosImage(cachedBytes, width, height);
    }

    _ohosFuture ??= _downloadImage(widget.imageUrl);

    return FutureBuilder<Uint8List>(
      future: _ohosFuture!,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return _buildOhosImage(snapshot.data!, width, height);
          }
          return _buildOhosErrorPlaceholder(width, height);
        }
        if (!widget.withHolder) {
          return SizedBox(
            width: width ?? widget.holderHeight,
            height: height ?? widget.holderHeight,
          );
        }
        return widget.imageUrl.endsWith('.svg')
            ? Loading()
            : _buildOhosLoadingPlaceholder(width, height);
      },
    );
  }

  Widget _buildOhosLoadingPlaceholder(double? width, double? height) {
    final background =
        WpyTheme.of(context).get(WpyColorKey.secondaryBackgroundColor);
    final highlight =
        WpyTheme.of(context).get(WpyColorKey.secondaryInfoTextColor);
    return SizedBox(
      width: width ?? widget.holderHeight,
      height: height ?? widget.holderHeight,
      child: Shimmer.fromColors(
        baseColor: background,
        highlightColor: highlight,
        child: ColoredBox(color: background),
      ),
    );
  }

  Widget _buildOhosImage(Uint8List bytes, double? width, double? height) {
    if (widget.imageUrl.endsWith('.svg')) {
      return SvgPicture.memory(
        bytes,
        width: width,
        height: height,
        fit: widget.fit,
        alignment: widget.alignment,
      );
    }

    final imageWidget = Image.memory(
      bytes,
      width: width,
      height: height,
      fit: widget.fit,
      alignment: widget.alignment,
      cacheWidth: _cachePixelDimension(width),
      cacheHeight: _cachePixelDimension(height),
      errorBuilder: (context, exception, stacktrace) {
        return _buildOhosErrorPlaceholder(width, height);
      },
    );

    final imageBuilder = () {
      if (widget.reduce && WpyTheme.of(context).brightness == Brightness.dark)
        return ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.2),
            BlendMode.darken,
          ),
          child: imageWidget,
        );
      return imageWidget;
    };

    if (!widget.imageUrl.contains('#')) {
      return imageBuilder();
    }

    final tags = widget.imageUrl.split('#')[1].split(',');
    if (tags.contains("masked")) {
      return SizedBox(
          height: height,
          width: width,
          child: SpoilerMaskImage(child: imageBuilder()));
    }
    return imageBuilder();
  }

  Widget _buildOhosErrorPlaceholder(double? width, double? height) {
    return SizedBox(
      width: width ?? widget.holderHeight,
      height: height ?? widget.holderHeight,
      child: WpyPic.errorPlaceHolder,
    );
  }

  Future<Uint8List> _downloadImage(String url) {
    final cached = _ohosImageCache[url];
    if (cached != null) return Future.value(cached);

    final pending = _ohosImageRequests[url];
    if (pending != null) return pending;

    final future = () async {
      final file = await ImageCacheService.instance.ensureCached(url);
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        _ohosImageCache[url] = bytes;
      }
      return bytes;
    }();
    _ohosImageRequests[url] = future;
    future.then<void>(
      (_) {
        if (identical(_ohosImageRequests[url], future)) {
          _ohosImageRequests.remove(url);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_ohosImageRequests[url], future)) {
          _ohosImageRequests.remove(url);
        }
      },
    );
    return future;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrl.startsWith('assets')) {
      return Container(child: asset);
    }
    // CachedNetworkImage depends on path_provider -> MissingPluginException on OHOS
    if (widget.withCache && (Platform.isAndroid || Platform.isIOS)) {
      return Container(child: cachedNetwork);
    }
    // OHOS: use the persistent cache service for network images.
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Container(child: _ohosNetwork);
    }
    return Container(child: network);
  }
}
