# xiaxinfeixiang — 厦信飞翔讲座

[English](README.md)

**当前版本：v0.3.0**

> 厦门大学「厦信飞翔」统一平台（`unify.xmu.edu.cn`）讲座查询与报名辅助 Android 应用。

## 界面展示

<p align="center">
  <img src="home.jpg" alt="首页" width="32%" height="420" style="object-fit: cover;" />
  <img src="detail.jpg" alt="详情页" width="32%" height="420" style="object-fit: cover;" />
  <img src="profile.jpg" alt="我的" width="32%" height="420" style="object-fit: cover;" />
</p>

## 功能

- **报名讲座** — 列表来自 `GetUserActivities`；主讲人、地点、**状态**等与 `GetUserActivityCategory` 合并展示（报名未开始 / 进行中 / 已报名 / 已结束等），避免列表接口里全是「未报名」的误导
- **已签到讲座** — `MySignIn` 已签到记录
- **讲座详情** — 时间场次、简介等；开放报名时可 **一键报名**（`SignUp`）
- **详情页状态横幅** — 与列表逻辑一致
- **闹钟** — 报名或开讲前 20 / 10 / 2 分钟
- **日历** — 报名开始或讲座开始提醒
- **分享** — 系统分享讲座摘要
- **我的** — 头像、姓名、学号、手机、邮箱
- **Cookie** — `shared_preferences` 本地保存

## 平台

仅 Android（校园网 HTTP 明文；Web 端不做支持）。

## 获取 Cookie（Wireshark）

1. 安装 [Wireshark](https://www.wireshark.org/)。
2. 电脑微信打开「厦信飞翔」服务号并登录。
3. 选对网卡抓包，在微信里打开/刷新页面。
4. 过滤 `http` 或统一平台域名，点开请求 → **HTTP** → 复制完整 `Cookie`。

## 运行

```bash
flutter pub get
flutter run
```

## 打包正式 APK

```bash
flutter build apk --release
```

默认输出：`build/app/outputs/flutter-apk/app-release.apk`  
GitHub Release 附件名为：`xiaxinfeixiang-lecture.apk`（同一文件重命名）。

## 版本发布

在 `main` 上打 `v*` 标签会触发 CI 构建并上传 `xiaxinfeixiang-lecture.apk`（见 `.github/workflows/android.yml`）。

## 配置 Cookie

任意页右上角 Cookie 图标，或 **我的 → Cookie**，粘贴完整 Cookie 后保存。  
示例：`deviceKey=951b74c7-f351-4704-a20c-b434f85ddcbe`  
Cookie 会过期，请求失败时需重新抓包更新。
