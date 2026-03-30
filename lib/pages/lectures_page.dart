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
  String? _error;
  List<Map<String, dynamic>> _mySignUps = const [];
  List<Map<String, dynamic>> _mySignIns = const [];
  Map<String, String> _signUpBeginById = const {};

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
        _mySignUps = const [];
        _mySignIns = const [];
        _signUpBeginById = const {};
      });
      return;
    }
    await _loadCookieOnly();
    final cookie = (_cookie ?? '').trim();
    if (cookie.isEmpty) {
      setState(() {
        _loading = false;
        _mySignUps = const [];
        _mySignIns = const [];
        _signUpBeginById = const {};
      });
      return;
    }
    try {
      final signUpRes = await _api.mySignUp(cookie: cookie);
      if (signUpRes['success'] != true) {
        setState(() {
          _loading = false;
          _error = (signUpRes['msg'] ?? '请求失败').toString();
        });
        return;
      }

      final dataList = (signUpRes['data'] is List) ? (signUpRes['data'] as List) : const [];
      final signUps = <Map<String, dynamic>>[];
      for (final row in dataList) {
        if (row is Map) signUps.add(row.cast<String, dynamic>());
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
        _mySignUps = signUps;
        _mySignIns = signIns;
      });

      final signUpBeginById = await _loadSignUpBegins(cookie, signUps);
      if (!mounted) return;
      setState(() => _signUpBeginById = signUpBeginById);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<Map<String, String>> _loadSignUpBegins(String cookie, List<Map<String, dynamic>> signUps) async {
    final ids = <String>{};
    for (final row in signUps) {
      final id = _pickStr(row, ['ActivityCategoryId', 'ActivityId', 'Id', 'ID', 'id']);
      if (UnifyApi.isUuid(id)) ids.add(id);
    }
    final list = ids.toList();
    if (list.isEmpty) return const {};

    final out = <String, String>{};
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
        if (s.isNotEmpty) out[x.id] = s;
      }
    }
    return out;
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('保存'),
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
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!cookieOk) const Center(child: Padding(padding: EdgeInsets.only(top: 48), child: Text('请先在右上角输入 Cookie'))),
            if (cookieOk && !_loading && _error != null)
              Center(child: Padding(padding: const EdgeInsets.only(top: 48), child: Text(_error!))),
            if (cookieOk && !_loading && _error == null) ...[
              const Text('已报名讲座', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (_mySignUps.isEmpty) const Text('暂无'),
              for (final row in _mySignUps) ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    title: Text(_pickStr(row, ['Name', 'Title', 'title'])),
                    key: ValueKey(_pickStr(row, ['ActivityCategoryId', 'ActivityId', 'Id', 'ID', 'id'])),
                    subtitle: Text([
                      '主讲人：${_pickStr(row, ['Hoster'])}',
                      '报名开始：${_signUpBeginById[_pickStr(row, ['ActivityCategoryId', 'ActivityId', 'Id', 'ID', 'id'])] ?? ''}',
                      '地点：${_pickStr(row, ['Address'])}',
                      '状态：${_pickStr(row, ['State'])}',
                    ].where((e) => e.trim().isNotEmpty).join('\n')),
                    onTap: () {
                      final id = _pickStr(row, ['ActivityCategoryId', 'ActivityId', 'Id', 'ID', 'id']);
                      if (!UnifyApi.isUuid(id)) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LectureDetailPage(id: id, title: _pickStr(row, ['Name'])),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('已签到讲座', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (_mySignIns.isEmpty) const Text('暂无'),
              for (final row in _mySignIns) ...[
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
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

