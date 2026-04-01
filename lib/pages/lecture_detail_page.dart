import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:share_plus/share_plus.dart';
import 'package:xiaxinfeixiang/api/unify_api.dart';
import 'package:xiaxinfeixiang/storage/cookie_store.dart';

enum _AlarmKind { lecture, signIn }
enum _CalendarKind { lecture, signUp }

class LectureDetailPage extends StatefulWidget {
  const LectureDetailPage({super.key, required this.id, required this.title});

  final String id;
  final String title;

  @override
  State<LectureDetailPage> createState() => _LectureDetailPageState();
}

class _LectureDetailPageState extends State<LectureDetailPage> {
  final _api = UnifyApi();

  bool _loading = true;
  bool _signingUp = false;
  String? _error;
  Map<String, dynamic>? _res;

  DateTime? _parseXmuDateTime(String s) {
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})\s+(\d{1,2}):(\d{1,2})(?::(\d{1,2}))?$')
        .firstMatch(s.trim());
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      int.parse(m.group(4)!),
      int.parse(m.group(5)!),
      int.parse(m.group(6) ?? '0'),
    );
  }

  DateTime? _pickActivityBegin(List activities, Map<String, dynamic>? data) {
    DateTime? best;
    final now = DateTime.now();
    for (final a in activities) {
      if (a is! Map) continue;
      final s = (a['BeginOn'] ?? '').toString();
      final dt = _parseXmuDateTime(s);
      if (dt == null) continue;
      if (dt.isBefore(now)) continue;
      if (best == null || dt.isBefore(best)) best = dt;
    }
    if (best != null) return best;
    final fallback = _parseXmuDateTime((data?['BeginOn'] ?? '').toString());
    return fallback;
  }

  Widget _statusBanner({
    required Color color,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }

  Widget? _buildEmphasis({
    required Map<String, dynamic>? res,
    required Map<String, dynamic>? data,
    required List activities,
    required DateTime? beginOn,
  }) {
    final now = DateTime.now();
    final isSignUp = (res?['isSignUp'] == true) || (data?['IsSignUp'] == true);
    final signUpBegin = _parseXmuDateTime((data?['SignUpBegin'] ?? '').toString());
    final signUpEnd = _parseXmuDateTime((data?['SignUpEnd'] ?? '').toString());

    if (signUpBegin != null && now.isBefore(signUpBegin)) {
      return _statusBanner(
        color: const Color(0xFF1976D2),
        icon: Icons.lock_clock,
        text: '报名未开始（${signUpBegin.toString().replaceFirst(".000", "")}）',
      );
    }
    if (!isSignUp && signUpBegin != null && signUpEnd != null && now.isAfter(signUpBegin) && now.isBefore(signUpEnd)) {
      return _statusBanner(
        color: const Color(0xFF2E7D32),
        icon: Icons.how_to_reg,
        text: '报名进行中',
      );
    }
    if (isSignUp) {
      if (beginOn != null && now.isBefore(beginOn)) {
        return _statusBanner(
          color: const Color(0xFF2E7D32),
          icon: Icons.check_circle,
          text: '已报名，未到签到时间',
        );
      }
      return _statusBanner(
        color: const Color(0xFF2E7D32),
        icon: Icons.check_circle,
        text: '已报名',
      );
    }
    if (signUpEnd != null && now.isAfter(signUpEnd)) {
      return _statusBanner(
        color: const Color(0xFF616161),
        icon: Icons.event_busy,
        text: '报名已结束',
      );
    }
    return null;
  }

  Future<void> _setAlarm({
    required DateTime when,
    required String message,
  }) async {
    final intent = AndroidIntent(
      action: 'android.intent.action.SET_ALARM',
      arguments: <String, dynamic>{
        'android.intent.extra.alarm.MESSAGE': message,
        'android.intent.extra.alarm.HOUR': when.hour,
        'android.intent.extra.alarm.MINUTES': when.minute,
        'android.intent.extra.alarm.DAY': when.day,
        'android.intent.extra.alarm.MONTH': when.month,
        'android.intent.extra.alarm.YEAR': when.year,
        'android.intent.extra.alarm.SKIP_UI': false,
      },
    );
    try {
      await intent.launch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _share(String text) async {
    try {
      await Share.share(text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _addCalendarEvent({
    required DateTime start,
    required DateTime end,
    required String title,
    required String description,
    required String location,
  }) async {
    final intent = AndroidIntent(
      action: 'android.intent.action.INSERT',
      data: 'content://com.android.calendar/events',
      arguments: <String, dynamic>{
        'title': title,
        'description': description,
        'eventLocation': location,
        'beginTime': start.millisecondsSinceEpoch,
        'endTime': end.millisecondsSinceEpoch,
      },
    );
    try {
      await intent.launch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openCalendarSheet({
    required _CalendarKind kind,
    required String name,
    required String hoster,
    required String address,
    required DateTime baseTime,
  }) async {
    final isSignUp = kind == _CalendarKind.signUp;
    final kindText = isSignUp ? '报名开始' : '讲座开始';
    final base = [
      name.trim(),
      if (hoster.trim().isNotEmpty) '主讲人：${hoster.trim()}',
      if (address.trim().isNotEmpty) '地点：${address.trim()}',
    ].where((e) => e.isNotEmpty).join(' ');

    Future<void> createWithOffset(int minutes) async {
      final start = baseTime.subtract(Duration(minutes: minutes));
      final end = start.add(const Duration(minutes: 10));
      await _addCalendarEvent(
        start: start,
        end: end,
        title: '$kindText提醒（提前$minutes分钟）',
        description: base,
        location: address.trim(),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.event),
              title: Text('$kindText前20分钟'),
              onTap: () async {
                Navigator.pop(context);
                await createWithOffset(20);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: Text('$kindText前10分钟'),
              onTap: () async {
                Navigator.pop(context);
                await createWithOffset(10);
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: Text('$kindText前2分钟'),
              onTap: () async {
                Navigator.pop(context);
                await createWithOffset(2);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAlarmSheet({
    required _AlarmKind kind,
    required String name,
    required String hoster,
    required String address,
    required DateTime baseTime,
    DateTime? signUpEnd,
  }) async {
    if (kind == _AlarmKind.lecture && signUpEnd != null && DateTime.now().isAfter(signUpEnd)) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('报名已结束'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }

    final base = [
      name.trim(),
      if (hoster.trim().isNotEmpty) '主讲人：${hoster.trim()}',
      if (address.trim().isNotEmpty) '地点：${address.trim()}',
    ].where((e) => e.isNotEmpty).join(' ');

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final kindText = kind == _AlarmKind.lecture ? '报名' : '签到';
        final t20 = kind == _AlarmKind.lecture ? '报名开始前20分钟' : '讲座前20分钟';
        final t10 = kind == _AlarmKind.lecture ? '报名开始前10分钟' : '讲座前10分钟';
        final t2 = kind == _AlarmKind.lecture ? '报名开始前2分钟' : '讲座前2分钟';
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  '提示：部分手机闹钟不支持自动设置日期，请在闹钟里手动修改日期',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.alarm),
                title: Text(t20),
                onTap: () async {
                  Navigator.pop(context);
                  await _setAlarm(
                    when: baseTime.subtract(const Duration(minutes: 20)),
                    message: '$kindText提醒(20分钟) $base',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.alarm),
                title: Text(t10),
                onTap: () async {
                  Navigator.pop(context);
                  await _setAlarm(
                    when: baseTime.subtract(const Duration(minutes: 10)),
                    message: '$kindText提醒(10分钟) $base',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.alarm),
                title: Text(t2),
                onTap: () async {
                  Navigator.pop(context);
                  await _setAlarm(
                    when: baseTime.subtract(const Duration(minutes: 2)),
                    message: '$kindText提醒(2分钟) $base',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _signUpEnabled(Map<String, dynamic>? res, Map<String, dynamic>? data) {
    final isSignUp = (res?['isSignUp'] == true) || (data?['IsSignUp'] == true);
    if (isSignUp) return false;
    final now = DateTime.now();
    final b = _parseXmuDateTime((data?['SignUpBegin'] ?? '').toString());
    final e = _parseXmuDateTime((data?['SignUpEnd'] ?? '').toString());
    if (b == null) return false;
    if (now.isBefore(b)) return false;
    if (e != null && now.isAfter(e)) return false;
    return true;
  }

  String _signUpLabel(Map<String, dynamic>? res, Map<String, dynamic>? data) {
    final isSignUp = (res?['isSignUp'] == true) || (data?['IsSignUp'] == true);
    if (isSignUp) return '已报名';
    final now = DateTime.now();
    final b = _parseXmuDateTime((data?['SignUpBegin'] ?? '').toString());
    final e = _parseXmuDateTime((data?['SignUpEnd'] ?? '').toString());
    if (b == null) return '暂不可报名';
    if (now.isBefore(b)) return '报名未开始';
    if (e != null && now.isAfter(e)) return '报名已结束';
    return '立即报名';
  }

  Future<void> _submitSignUp() async {
    if (_signingUp) return;
    final cookie = (await CookieStore.getCookie())?.trim();
    if (!mounted) return;
    if (cookie == null || cookie.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先设置 Cookie')));
      return;
    }
    setState(() => _signingUp = true);
    try {
      final out = await _api.signUp(cookie: cookie, id: widget.id);
      if (!mounted) return;
      final ok = out['success'] == true;
      final msg = (out['msg'] ?? (ok ? '报名成功' : '报名失败')).toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (ok) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _signingUp = false);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (kIsWeb) {
      setState(() {
        _loading = false;
        _error = '仅支持 Android（Web 端会被浏览器限制拦截）';
      });
      return;
    }
    final cookie = await CookieStore.getCookie();
    if (!mounted) return;
    if ((cookie ?? '').trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = '请先设置 Cookie';
      });
      return;
    }
    try {
      final res = await _api.getUserActivityCategory(cookie: cookie!.trim(), id: widget.id);
      if (!mounted) return;
      if (res['success'] != true) {
        setState(() {
          _loading = false;
          _error = (res['msg'] ?? '请求失败').toString();
          _res = res;
        });
        return;
      }
      if (res['data'] is! Map) {
        setState(() {
          _loading = false;
          _error = 'Cookie 错误或已过期';
          _res = res;
        });
        return;
      }
      setState(() {
        _loading = false;
        _res = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _stripHtml(String v) {
    final s = v
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final res = _res;
    final data = (res?['data'] is Map) ? (res!['data'] as Map).cast<String, dynamic>() : null;
    final activities = (res?['activities'] is List) ? (res!['activities'] as List) : const [];

    final name = (data?['Name'] ?? widget.title).toString();
    final hoster = (data?['Hoster'] ?? '').toString();
    final address = (data?['Address'] ?? '').toString();
    final signUpBegin = (data?['SignUpBegin'] ?? '').toString();
    final signUpEnd = (data?['SignUpEnd'] ?? '').toString();
    final signUpBeginDt = _parseXmuDateTime(signUpBegin);
    final contentHtml = (data?['Content'] ?? '').toString();
    final content = contentHtml.trim().isEmpty ? '' : _stripHtml(contentHtml);
    final beginOn = _pickActivityBegin(activities, data);
    final emphasis = _buildEmphasis(res: res, data: data, activities: activities, beginOn: beginOn);
    final shareText = [
      name.trim(),
      if (hoster.trim().isNotEmpty) '主讲人：${hoster.trim()}',
      if (address.trim().isNotEmpty) '地点：${address.trim()}',
      if (signUpBegin.trim().isNotEmpty) '报名开始：${signUpBegin.trim()}',
      if (beginOn != null) '开始时间：${beginOn.toString().replaceFirst(".000", "")}',
    ].where((e) => e.isNotEmpty).join('\n');

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: '分享',
            onPressed: () async => _share(shareText),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_loading && _error != null)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(_error!),
                  ),
                ),
              ),
            if (!_loading && _error == null) ...[
              if (emphasis != null) ...[
                emphasis,
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_signingUp || !_signUpEnabled(res, data)) ? null : _submitSignUp,
                  icon: _signingUp
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.how_to_reg),
                  label: Text(_signingUp ? '提交中…' : _signUpLabel(res, data)),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    if (hoster.trim().isNotEmpty) _infoTile(icon: Icons.mic_outlined, title: '主讲人', value: hoster),
                    if (address.trim().isNotEmpty) _infoTile(icon: Icons.place_outlined, title: '地点', value: address),
                    if (signUpBegin.trim().isNotEmpty || signUpEnd.trim().isNotEmpty)
                      _infoTile(
                        icon: Icons.how_to_reg_outlined,
                        title: '报名时间',
                        value: [signUpBegin, signUpEnd].where((e) => e.trim().isNotEmpty).join(' - '),
                      ),
                  ],
                ),
              ),
              if (content.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('详情', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        SelectableText(content),
                      ],
                    ),
                  ),
                ),
              ],
              if (activities.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('场次', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        for (final a in activities)
                          if (a is Map)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text((a['Name'] ?? '').toString().trim().isEmpty ? name : (a['Name'] ?? name).toString()),
                              subtitle: Text([
                                (a['State'] ?? '').toString(),
                                (a['BeginOn'] ?? '').toString(),
                                (a['EndOn'] ?? '').toString(),
                              ].where((e) => e.trim().isNotEmpty).join('  ')),
                            ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: signUpBeginDt == null
                    ? null
                    : () => _openAlarmSheet(
                          kind: _AlarmKind.lecture,
                          name: name,
                          hoster: hoster,
                          address: address,
                          baseTime: signUpBeginDt,
                          signUpEnd: _parseXmuDateTime(signUpEnd),
                        ),
                icon: const Icon(Icons.alarm_add),
                label: const Text('设置讲座报名提醒闹钟'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: beginOn == null
                    ? null
                    : () => _openAlarmSheet(
                          kind: _AlarmKind.signIn,
                          name: name,
                          hoster: hoster,
                          address: address,
                          baseTime: beginOn,
                        ),
                icon: const Icon(Icons.alarm_add),
                label: const Text('设置讲座签到闹钟'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: signUpBeginDt == null
                    ? null
                    : () => _openCalendarSheet(
                          kind: _CalendarKind.signUp,
                          name: name,
                          hoster: hoster,
                          address: address,
                          baseTime: signUpBeginDt,
                        ),
                icon: const Icon(Icons.calendar_month),
                label: const Text('将报名开始时间添加到日历'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: beginOn == null
                    ? null
                    : () => _openCalendarSheet(
                          kind: _CalendarKind.lecture,
                          name: name,
                          hoster: hoster,
                          address: address,
                          baseTime: beginOn,
                        ),
                icon: const Icon(Icons.calendar_month),
                label: const Text('将讲座开始时间添加到日历'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

