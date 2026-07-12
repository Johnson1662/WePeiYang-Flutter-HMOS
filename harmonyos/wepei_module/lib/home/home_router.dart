import 'package:flutter/material.dart';
import 'package:wepei_module/commons/widgets/webview_page.dart';
import 'package:wepei_module/home/view/cas_qr_page.dart';

import 'view/home_page.dart';
import 'view/lost_and_found_home_page.dart';
import 'view/map_calendar_page.dart';
import 'view/web_views/fifty_two_hz_page.dart';
import 'view/web_views/game_page.dart';

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
    wiki: (_) => const WebViewPage(url: 'https://wiki.tjubot.cn/', title: '北洋维基'),
    mapCalenderPage: (_) => MapCalendarPage(),
    hz: (_) => FiftyTwoHzPage(),
    laf: (_) => LostAndFoundHomePage(),
    news: (_) => const WebViewPage(url: 'https://news.twt.edu.cn/', title: '天外天新闻网'),
    game: (_) => GamePage(),
    casQR: (_) => CasQRPage(),
  };
}
