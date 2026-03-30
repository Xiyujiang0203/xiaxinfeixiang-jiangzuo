# xiaxinfeixiang — 厦信飞翔讲座

[English](README.md)

> 厦门大学"厦信飞翔"平台讲座查询与管理 Android 应用。

## 界面展示

<p align="center">
  <img src="home.jpg" alt="首页" width="32%" height="420" style="object-fit: cover;" />
  <img src="detail.jpg" alt="详情页" width="32%" height="420" style="object-fit: cover;" />
  <img src="profile.jpg" alt="我的" width="32%" height="420" style="object-fit: cover;" />
</p>

## 功能

- **已报名讲座** — 查看所有已报名讲座，显示主讲人、报名开始时间、地点、状态
- **已签到讲座** — 查看已完成签到的讲座
- **讲座详情** — 主讲人、地点、报名时间段、场次列表、完整简介（自动去除 HTML 标签）
- **状态横幅** — 实时显示：报名未开始 / 报名进行中 / 报名已结束 / 已报名
- **闹钟提醒** — 一键设置讲座或签到前 20 / 10 / 2 分钟 Android 闹钟
- **分享** — 通过系统分享面板分享讲座信息（名称、主讲人、地点、开始时间）
- **我的** — 展示账号头像、姓名、学号、手机号、邮箱
- **Cookie 本地持久化** — 使用 `shared_preferences` 本地保存 Cookie

## 平台

Android 已支持。macOS / iOS / Windows / Web：待开发。

## 获取 Cookie（Wireshark 抓包）

1. 下载并安装 [Wireshark](https://www.wireshark.org/)（电脑端）。
2. 电脑版微信打开"厦信飞翔"服务号并登录。
3. 用 Wireshark 选择当前网络接口开始抓包。
4. 在微信里打开/刷新任意页面，过滤 `http` 或按域名过滤请求。
5. 点开任意请求 → 展开 **Hypertext Transfer Protocol** → 复制完整的 `Cookie` 字段值。

## 运行

```bash
flutter pub get
flutter run
```

## 打包 Android APK

```bash
flutter build apk --release
```

输出：`build/app/outputs/flutter-apk/app-release.apk`

## 配置 Cookie

任意页面点右上角 Cookie 图标，或进入**我的 → Cookie**，粘贴完整 Cookie 字符串后保存。
Cookie 格式示例：`deviceKey=951b74c7-f351-4704-a20c-b434f85ddcbe`

注意：Cookie 会过期，接口请求失败时需要重新抓包并更新 Cookie。
