import 'package:flutter/material.dart';
import 'package:xiaxinfeixiang/api/unify_api.dart';
import 'package:xiaxinfeixiang/storage/cookie_store.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _api = UnifyApi();
  String? _cookie;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _basic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await CookieStore.getCookie();
    if (!mounted) return;
    setState(() => _cookie = c);
    await _loadBasic();
  }

  Future<void> _loadBasic() async {
    final cookie = (_cookie ?? '').trim();
    if (cookie.isEmpty) {
      setState(() {
        _basic = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _api.getBasicConfig(cookie: cookie);
      if (!mounted) return;
      if (res['success'] != true) {
        setState(() {
          _loading = false;
          _basic = null;
          _error = (res['msg'] ?? '请求失败').toString();
        });
        return;
      }
      setState(() {
        _loading = false;
        _basic = res;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _basic = null;
        _error = e.toString();
      });
    }
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
    await _load();
  }

  String _pickStr(Map<String, dynamic>? m, String key) {
    final v = m?[key];
    if (v == null) return '';
    return v.toString().trim();
  }

  Widget _itemTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }

  Widget _cookieCard(bool cookieOk) {
    return Card(
      child: ListTile(
        leading: Icon(cookieOk ? Icons.check_circle : Icons.error_outline),
        title: const Text('Cookie'),
        subtitle: Text(cookieOk ? '已设置' : '未设置'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _editCookie,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cookieOk = (_cookie ?? '').trim().isNotEmpty;
    final userInfo = (_basic?['userInfo'] is Map)
        ? (_basic!['userInfo'] as Map).cast<String, dynamic>()
        : null;
    final realName = _pickStr(userInfo, 'realName');
    final userCode = _pickStr(userInfo, 'userCode');
    final mobile = _pickStr(userInfo, 'mobile');
    final email = _pickStr(userInfo, 'email');
    final avatar = _pickStr(userInfo, 'avatar');

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (cookieOk) ...[
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!_loading && _error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(_error!),
                    ),
                  ),
                ),
              if (!_loading && _error == null && userInfo != null)
                Card(
                  margin: const EdgeInsets.only(top: 2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      children: [
                        if (avatar.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 6),
                            child: CircleAvatar(
                              radius: 36,
                              backgroundImage: NetworkImage(avatar),
                            ),
                          ),
                        if (realName.isNotEmpty) _itemTile(icon: Icons.badge_outlined, title: '姓名', value: realName),
                        if (userCode.isNotEmpty)
                          _itemTile(icon: Icons.confirmation_number_outlined, title: '学号', value: userCode),
                        if (mobile.isNotEmpty) _itemTile(icon: Icons.phone_outlined, title: '手机号', value: mobile),
                        if (email.isNotEmpty) _itemTile(icon: Icons.email_outlined, title: '邮箱', value: email),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _cookieCard(cookieOk),
            ],
            if (!cookieOk) _cookieCard(cookieOk),
          ],
        ),
      ),
    );
  }
}

