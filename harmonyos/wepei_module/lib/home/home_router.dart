import 'dart:io';

import 'package:flutter/material.dart';
import 'package:wepei_module/commons/channel/image_save/image_save.dart';
import 'package:wepei_module/home/view/cas_qr_page.dart';

import 'view/home_page.dart';
import 'view/lost_and_found_home_page.dart';
import 'view/map_calendar_page.dart';
import 'view/web_views/fifty_two_hz_page.dart';
import 'view/web_views/game_page.dart';

/// A simple page that opens a URL via native WebView and pops back to Flutter.
class _NativeWebViewPage extends StatelessWidget {
  final String url;
  final String title;
  const _NativeWebViewPage({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    // Open in native ArkUI WebView (pushes on top of Flutter navigation stack)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ImageSave.openWebView(url);
    });
    // This page stays in the background while native WebPage shows on top
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class HomeRouter {
  static String home = 'home/home';
  static String wiki = 'home/wiki';
  static String hz = 'home/52hz';
  static String mapCalenderPage = 'home/mapCalenderPage';
  static String restartGame = 'home/restartGame';
  static String laf = 'home/laf';
  static String news = 'home/news';
  static String casQR = 'home/casQR';
  static String game = '';
  static final Map<String, Widget Function(dynamic arguments)> routers = {
    home: (args) => HomePage(args),
    wiki: (_) => const _NativeWebViewPage(url: 'https://wiki.tjubot.cn/', title: '北洋维基'),
    mapCalenderPage: (_) => MapCalendarPage(),
    hz: (_) => FiftyTwoHzPage(),
    laf: (_) => LostAndFoundHomePage(),
    news: (_) => const _NativeWebViewPage(url: 'https://news.twt.edu.cn/', title: '天外天新闻网'),
    game: (_) => GamePage(),
    casQR: (_) => CasQRPage(),
  };
}
