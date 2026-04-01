import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:xiaxinfeixiang/api/unify_api.dart';
import 'package:xiaxinfeixiang/pages/lecture_detail_page.dart';
import 'package:xiaxinfeixiang/storage/app_flags.dart';
import 'package:xiaxinfeixiang/storage/cookie_store.dart';

class LecturesPage extends StatefulWidget {
  const LecturesPage({super.key});

  @override
  State<LecturesPage> createState() => _LecturesPageState();
}

class _LecturesPageState extends State<LecturesPage> {
  final _api = UnifyApi();
  String? _cookie;

  bool _loading = false;
  bool _isPulling = false;
  String? _error;
  List<Map<String, dynamic>> _userActivities = const [];
  List<Map<String, dynamic>> _mySignIns = const [];
  Map<String, String> _signUpBeginById = const {};
  Map<String, String> _statusById = const {};

  @override
  void initState() {
    super.initState();
    _initOnce();
  }

  Future<void> _initOnce() async {
    await _loadCookieOnly();
    final cookieOk = (_cookie ?? '').trim().isNotEmpty;
    if (!cookieOk) return;
    if (await AppFlags.getAutoRefreshedOnce()) return;
    if (!mounted) return;
    await _loadAll();
    await AppFlags.setAutoRefreshedOnce();
  }

  Future<void> _loadCookieOnly() async {
    final c = await CookieStore.getCookie();
    if (!mounted) return;
    setState(() => _cookie = c);
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (kIsWeb) {
      setState(() {
        _loading = false;
        _error = '仅支持 Android（Web 端会被浏览器限制拦截）';
        _userActivities = const [];
        _mySignIns = const [];
        _signUpBeginById = const {};
        _statusById = const {};
      });
      return;
    }
    await _loadCookieOnly();
    final cookie = (_cookie ?? '').trim();
    if (cookie.isEmpty) {
      setState(() {
        _loading = false;
        _userActivities = const [];
        _mySignIns = const [];
        _signUpBeginById = const {};
        _statusById = const {};
      });
      return;
    }
    try {
      final actRes = await _api.getUserActivities(cookie: cookie);
      if (actRes['success'] != true) {
        setState(() {
          _loading = false;
          _error = (actRes['msg'] ?? '请求失败').toString();
        });
        return;
      }

      final dataList = (actRes['data'] is List) ? (actRes['data'] as List) : const [];
      final activities = <Map<String, dynamic>>[];
      for (final row in dataList) {
        if (row is Map) activities.add(row.cast<String, dynamic>());
      }

      final signInRes = await _api.mySignIn(cookie: cookie);
      if (signInRes['success'] != true) {
        setState(() {
          _loading = false;
          _error = (signInRes['msg'] ?? '请求失败').toString();
        });
        return;
      }

      final inList = (signInRes['data'] is List) ? (signInRes['data'] as List) : const [];
      final signIns = <Map<String, dynamic>>[];
      for (final row in inList) {
        if (row is Map) signIns.add(row.cast<String, dynamic>());
      }

      setState(() {
        _loading = false;
        _userActivities = activities;
        _mySignIns = signIns;
      });

      final enriched = await _loadCategoryEnrichment(cookie, activities);
      if (!mounted) return;
      setState(() {
        _signUpBeginById = enriched.signUpBeginById;
        _statusById = enriched.statusById;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

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
    return _parseXmuDateTime((data?['BeginOn'] ?? '').toString());
  }

  String _deriveStatusFromCategory(Map<String, dynamic> res) {
    final now = DateTime.now();
    final data = (res['data'] is Map) ? (res['data'] as Map).cast<String, dynamic>() : null;
    final activities = (res['activities'] is List) ? (res['activities'] as List) : const [];
    final isSignUp = (res['isSignUp'] == true) || (data?['IsSignUp'] == true);
    final signUpBegin = _parseXmuDateTime((data?['SignUpBegin'] ?? '').toString());
    final signUpEnd = _parseXmuDateTime((data?['SignUpEnd'] ?? '').toString());
    final beginOn = _pickActivityBegin(activities, data);

    if (signUpBegin != null && now.isBefore(signUpBegin)) return '报名未开始';
    if (!isSignUp &&
        signUpBegin != null &&
        signUpEnd != null &&
        now.isAfter(signUpBegin) &&
        now.isBefore(signUpEnd)) {
      return '报名进行中';
    }
    if (isSignUp) {
      if (beginOn != null && now.isBefore(beginOn)) return '已报名，未到签到时间';
      return '已报名';
    }
    if (signUpEnd != null && now.isAfter(signUpEnd)) return '报名已结束';
    return '未报名';
  }

  Future<({Map<String, String> signUpBeginById, Map<String, String> statusById})> _loadCategoryEnrichment(
    String cookie,
    List<Map<String, dynamic>> rows,
  ) async {
    final ids = <String>{};
    for (final row in rows) {
      final id = _pickStr(row, ['ActivityCategoryId', 'ActivityId', 'Id', 'ID', 'id']);
      if (UnifyApi.isUuid(id)) ids.add(id);
    }
    final list = ids.toList();
    if (list.isEmpty) {
      return (signUpBeginById: <String, String>{}, statusById: <String, String>{});
    }

    final signUpBeginById = <String, String>{};
    final statusById = <String, String>{};
    for (var i = 0; i < list.length; i += 6) {
      final chunk = list.sublist(i, (i + 6) > list.length ? list.length : (i + 6));
      final resList = await Future.wait(
        chunk.map((id) async {
          try {
            final res = await _api.getUserActivityCategory(cookie: cookie, id: id);
            return (id: id, res: res);
          } catch (_) {
            return (id: id, res: null);
          }
        }),
      );
      for (final x in resList) {
        final res = x.res;
        if (res is! Map<String, dynamic>) continue;
        if (res['success'] != true) continue;
        final data = (res['data'] is Map) ? (res['data'] as Map).cast<String, dynamic>() : null;
        final s = (data?['SignUpBegin'] ?? '').toString().trim();
        if (s.isNotEmpty) signUpBeginById[x.id] = s;
        statusById[x.id] = _deriveStatusFromCategory(res);
      }
    }
    return (signUpBeginById: signUpBeginById, statusById: statusById);
  }

  Future<void> _editCookie() async {
    final controller = TextEditingController(text: _cookie ?? '');
    final v = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('输入 Cookie'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'deviceKey=...'),
            maxLines: 3,
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context, controller.text),
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        );
      },
    );
    if (v == null) return;
    await CookieStore.setCookie(v);
    await _loadAll();
  }

  String _pickStr(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _hintCard(String text, {IconData icon = Icons.info_outline}) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cookieOk = (_cookie ?? '').trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('厦信飞翔讲座'),
        actions: [
          IconButton(
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
          IconButton(
            onPressed: _editCookie,
            icon: const Icon(Icons.cookie),
            tooltip: 'Cookie',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _isPulling = true);
          await _loadAll();
          if (mounted) setState(() => _isPulling = false);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!cookieOk) ...[
              const SizedBox(height: 32),
              _hintCard('请先在右上角输入 Cookie', icon: Icons.cookie_outlined),
            ],
            if (cookieOk && !_loading && _error != null)
              Padding(
                padding: const EdgeInsets.only(top: 32),
                child: _hintCard(_error!, icon: Icons.error_outline),
              ),
            if (cookieOk && _loading && !_isPulling)
              const Padding(
                padding: EdgeInsets.only(top: 36),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (cookieOk && !_loading && _error == null) ...[
              _sectionTitle('报名讲座', Icons.how_to_reg),
              if (_userActivities.isEmpty) _hintCard('暂无讲座', icon: Icons.inbox_outlined),
              for (final row in _userActivities) ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    title: Text(_pickStr(row, ['Name', 'Title', 'title'])),
                    key: ValueKey(_pickStr(row, ['ActivityCategoryId', 'ActivityId', 'Id', 'ID', 'id'])),
                    subtitle: Text(() {
                      final id = _pickStr(row, ['ActivityCategoryId', 'ActivityId', 'Id', 'ID', 'id']);
                      final st = (_statusById[id] ?? _pickStr(row, ['State'])).trim();
                      return [
                        '主讲人：${_pickStr(row, ['Hoster'])}',
                        '报名开始：${_signUpBeginById[id] ?? ''}',
                        '地点：${_pickStr(row, ['Address'])}',
                        if (st.isNotEmpty) '状态：$st',
                      ].where((e) => e.trim().isNotEmpty).join('\n');
                    }()),
                    onTap: () {
                      final id = _pickStr(row, ['ActivityCategoryId', 'ActivityId', 'Id', 'ID', 'id']);
                      if (!UnifyApi.isUuid(id)) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LectureDetailPage(id: id, title: _pickStr(row, ['Name'])),
                        ),
                      );
                    },
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _sectionTitle('已签到讲座', Icons.task_alt),
              if (_mySignIns.isEmpty) _hintCard('暂无已签到讲座', icon: Icons.inbox_outlined),
              for (final row in _mySignIns) ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    title: Text(_pickStr(row, ['Name', 'Title', 'title'])),
                    subtitle: Text([
                      '主讲人：${_pickStr(row, ['Hoster'])}',
                      '地点：${_pickStr(row, ['Address'])}',
                      '状态：${_pickStr(row, ['State'])}',
                    ].where((e) => e.trim().isNotEmpty).join('\n')),
                    onTap: () {
                      final id = _pickStr(row, ['ActivityCategoryId', 'ActivityId', 'Id', 'ID', 'id']);
                      final title = _pickStr(row, ['Name', 'Title', 'title']);
                      if (!UnifyApi.isUuid(id)) return;
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => LectureDetailPage(id: id, title: title)));
                    },
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

