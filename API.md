# 厦门大学统一平台（unify.xmu.edu.cn）相关 HTTP 接口说明

> 依据本仓库 `main.js` 调用方式与 `http.pcapng` 抓包整理；仅供对接自用脚本时参考，非官方文档。

## 基础信息

| 项 | 值 |
| --- | --- |
| 基址 | `http://unify.xmu.edu.cn` 或 `https://unify.xmu.edu.cn`（以实际访问为准） |
| 鉴权 | 请求头 `Cookie` 需携带有效 `deviceKey=...`（通常与微信内登录态一致） |
| 表单接口 | `Content-Type: application/x-www-form-urlencoded` |
| JSON 响应 | 多数 `/api/*` 返回 `application/json`，根字段常见 `success`、`msg`、`data` 等 |

### 建议请求头（POST 表单）

```
Host: unify.xmu.edu.cn
Cookie: deviceKey=<你的 deviceKey>
Content-Type: application/x-www-form-urlencoded
```

### 微信入口（抓包中的登录前链路）

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/r/{短链码}` | 短链跳转 |
| GET | `/uc/wechatlogin` | 查询参数 `code`、`state`（微信 OAuth 回调），成功后服务端写入 Cookie |

---

## 页面路由（无服务端渲染数据）

以下返回 **SPA 壳 HTML**（空 `#app` + 静态 JS），**不含**讲座正文或详情 JSON；爬虫请改调下方 API。

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/mob/iuc/lecture/myLecture` | 讲座列表页入口 |
| GET | `/mob/iuc/lecture/detail` | 查询参数 `id`（活动/分类 UUID），详情页入口 |

---

## API 列表

### 1. 获取基础配置

| 项 | 内容 |
| --- | --- |
| 路径 | `POST /api/config/GetBasicConfig` |
| Body | 可为空字符串 `""`；抓包中亦见 `deviceKey=` 形式 |
| 说明 | 站点标题、当前用户 `userInfo`（含 `token`、`realName` 等） |

---

### 2. 获取文章列表（CMS）

| 项 | 内容 |
| --- | --- |
| 路径 | `POST /api/cms/getArticles` |
| Body（示例） | `page=1&pageSize=5&deviceKey=` |
| 说明 | 抓包中与 `GetBasicConfig` 后并行出现；分页参数以实际页面为准 |

---

### 3. 获取应用状态

| 项 | 内容 |
| --- | --- |
| 路径 | `POST /api/ywck/GetApplicationStatus` |
| Body（示例） | `deviceKey=` 或空 |
| 说明 | 抓包中与 `getArticles` 几乎同时发起 |

---

### 4. 我的报名记录

| 项 | 内容 |
| --- | --- |
| 路径 | `POST /api/activity/MySignUp` |
| Body（示例） | `page=1&pageSize=100` |
| 说明 | 列表在 `data`；单条常见字段含 `ActivityCategoryId`、`Name`、`State`、`BeginOn`、`Address`、`Hoster` 等；另有 `totalRow`、`delay.miss` 等 |

---

### 5. 我的签到记录

| 项 | 内容 |
| --- | --- |
| 路径 | `POST /api/activity/MySignIn` |
| Body（示例） | `page=1&pageSize=100` |
| 说明 | 结构与报名类似；`data` 中含 `SignInOn`、`State` 等 |

---

### 6. 活动分类 / 讲座详情（JSON）

| 项 | 内容 |
| --- | --- |
| 路径 | `POST /api/activity/GetUserActivityCategory` |
| Body（必填含义） | `id=<UUID>&deviceKey=` |
| 参数 | `id`：与 `MySignUp` / `MySignIn` 中 `ActivityCategoryId` 一致（或与详情页 URL 中 `id` 一致） |
| 说明 | **打开 `/mob/iuc/lecture/detail?id=...` 后，浏览器实际用本接口拉详情**；`id` 为空或非法 UUID 时可能返回 `success: false` 及「找不到对象」类 `msg` |
| 响应要点 | `success`、`data`（内含活动/分类详情字段，如 `ID`、`ParentId`、`isSignUp`、`signUpCount` 等，以实际 JSON 为准） |

---

## 调用顺序参考（与抓包一致）

1. （可选）短链 → `wechatlogin` 完成 Cookie  
2. `GetBasicConfig`  
3. `getArticles` 与 `GetApplicationStatus` 并行（若需与客户端一致）  
4. `MySignUp` 与 `MySignIn` 并行  
5. 对每个目标 UUID：`GetUserActivityCategory`，`body` 为 `id=<UUID>&deviceKey=`

---

## 字段与 ID 说明

- 列表里的 **`ActivityCategoryId`** 可作为详情接口的 **`id`**。  
- **`/mob/iuc/lecture/detail`** 仅用于人类在浏览器中打开页面，**不可替代** `GetUserActivityCategory` 获取 JSON 详情。
