import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UnifyApi {
  UnifyApi({
    http.Client? client,
    String? baseUrl,
    bool? useProxy,
  })  : _client = client ?? http.Client(),
        useProxy = useProxy ?? kIsWeb,
        baseUrl =
            baseUrl ?? (kIsWeb ? Uri.base.origin : 'http://unify.xmu.edu.cn');

  final http.Client _client;
  final String baseUrl;
  final bool useProxy;

  static final _uuidRe = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool isUuid(String? v) {
    if (v == null) return false;
    return _uuidRe.hasMatch(v.trim());
  }

  Map<String, String> _headers(String cookie) {
    final h = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
    };
    if (useProxy) {
      h['X-Cookie'] = cookie;
      return h;
    }
    h['Cookie'] = cookie;
    return h;
  }

  Future<Map<String, dynamic>> _postForm(
    String path,
    String cookie, {
    Map<String, String>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await _client
        .post(uri, headers: _headers(cookie), body: body ?? const {})
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('http_${res.statusCode}');
    }
    final text = res.body;
    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;
    throw FormatException('unexpected_json_root');
  }

  Future<Map<String, dynamic>> mySignUp({
    required String cookie,
    int page = 1,
    int pageSize = 100,
  }) {
    return _postForm(
      '/api/activity/MySignUp',
      cookie,
      body: {
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
  }

  Future<Map<String, dynamic>> getUserActivities({
    required String cookie,
    int page = 1,
    int pageSize = 500,
  }) {
    return _postForm(
      '/api/activity/GetUserActivities',
      cookie,
      body: {
        'page': '$page',
        'pageSize': '$pageSize',
        'deviceKey': '',
      },
    );
  }

  Future<Map<String, dynamic>> mySignIn({
    required String cookie,
    int page = 1,
    int pageSize = 100,
  }) {
    return _postForm(
      '/api/activity/MySignIn',
      cookie,
      body: {
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
  }

  Future<Map<String, dynamic>> getBasicConfig({
    required String cookie,
  }) {
    return _postForm(
      '/api/config/GetBasicConfig',
      cookie,
      body: const {},
    );
  }

  Future<Map<String, dynamic>> getArticles({
    required String cookie,
    int page = 1,
    int pageSize = 20,
  }) {
    return _postForm(
      '/api/cms/getArticles',
      cookie,
      body: {
        'page': '$page',
        'pageSize': '$pageSize',
        'deviceKey': '',
      },
    );
  }

  Future<Map<String, dynamic>> getUserActivityCategory({
    required String cookie,
    required String id,
  }) {
    return _postForm(
      '/api/activity/GetUserActivityCategory',
      cookie,
      body: {
        'id': id,
        'deviceKey': '',
      },
    );
  }

  Future<Map<String, dynamic>> signUp({
    required String cookie,
    required String id,
    int state = 0,
  }) {
    return _postForm(
      '/api/activity/SignUp',
      cookie,
      body: {
        'state': '$state',
        'id': id,
        'deviceKey': '',
      },
    );
  }
}

class HttpException implements Exception {
  HttpException(this.message);
  final String message;
  @override
  String toString() => message;
}

