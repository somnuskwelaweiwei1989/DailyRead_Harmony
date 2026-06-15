# DailyRead · 每日阅读（鸿蒙端）

> 基于 HarmonyOS ArkTS 开发的每日阅读应用，支持文章阅读、背概念、背穴位、WebDAV 云同步等功能。

---

## 📖 项目简介

DailyRead 是一款面向日常阅读习惯养成的应用，用户可以：

- 📚 添加并阅读文章，每日自动生成今日阅读任务
- 🧠 管理和背诵概念数据（可按分类、学科、章节筛选）
- 📍 背诵人体穴位数据（内置常用穴位库）
- ☁️ 通过 WebDAV 协议与 Windows 端/其他设备同步数据（支持坚果云等主流 WebDAV 服务）
- 💾 本地 JSON 导入/导出数据

---

## 🏗 技术栈

| 技术 | 版本/说明 |
|------|----------|
| 开发平台 | HarmonyOS / OpenHarmony |
| 开发语言 | ArkTS (TypeScript 超集) |
| UI 框架 | ArkUI（声明式开发范式） |
| 数据库 | SQLite（ArkTS 关系型数据 RdbStore API，启用 WAL 模式） |
| 网络协议 | WebDAV (HTTP/HTTPS) |
| 构建工具 | DevEco Studio + hvigor |

---

## 📂 目录结构

```
DailyRead_Harmony/
├── entry/                          # 主模块
│   └── src/main/ets/
│       ├── entryability/           # 应用入口能力
│       │   ├── EntryAbility.ets
│       │   └── EntryBackupAbility.ets
│       ├── pages/                  # 页面
│       │   ├── SplashPage.ets      # 启动页
│       │   ├── Index.ets           # 路由分发
│       │   ├── Home.ets            # 首页 - 今日阅读
│       │   ├── Reader.ets          # 文章阅读页
│       │   ├── ArticleManage.ets   # 文章管理
│       │   ├── RandomRead.ets      # 随心阅读
│       │   ├── ConceptStudy.ets    # 背概念
│       │   ├── ConceptSettings.ets # 概念管理
│       │   ├── AcupointStudy.ets   # 背穴位
│       │   └── Settings.ets        # 设置页（含 WebDAV 配置与备份）
│       ├── model/                  # 数据模型
│       │   ├── Article.ets         # 文章
│       │   ├── Concept.ets         # 概念
│       │   ├── Acupoint.ets        # 穴位
│       │   ├── Config.ets          # 应用配置
│       │   ├── CheckInRecord.ets   # 打卡记录
│       │   ├── BuiltInAcupoint.ets # 内置穴位
│       │   ├── RawAcupoint.ets     # 原始穴位数据
│       │   └── PickResult.ets      # 抽取结果
│       ├── repository/             # 数据访问层
│       │   ├── ArticleRepository.ets
│       │   ├── ConceptRepository.ets
│       │   ├── AcupointRepository.ets
│       │   ├── ConfigRepository.ets
│       │   ├── CheckInRepository.ets
│       │   ├── DailyTaskRepository.ets
│       │   └── BuiltInAcupointStore.ets
│       ├── service/                # 业务服务层
│       │   ├── DailyTaskService.ets   # 今日任务生成逻辑
│       │   ├── BackupService.ets      # JSON 导入/导出
│       │   ├── WebDavSyncService.ets  # WebDAV 同步
│       │   └── WebDavClient.ets       # WebDAV HTTP 客户端
│       └── database/
│           └── AppDatabase.ets      # 数据库初始化、表结构、升级逻辑
├── entry/src/main/resources/        # 资源文件（图片、字符串、颜色）
│   └── rawfile/                     # 原始资源（01.png~03.png 用于坚果云指引，acupoints.json 内置穴位）
├── AppScope/                        # 应用级配置
│   └── resources/base/media/logo.png  # 应用图标
├── build-profile.json5
├── hvigorfile.ts
├── oh-package.json5
└── daily_read_backup_windows.json   # Windows 端备份示例
```

---

## 💾 数据模型与字段说明

### Article（文章）

定义于 [entry/src/main/ets/model/Article.ets](entry/src/main/ets/model/Article.ets)

| 字段 | 类型 | 含义 |
|------|------|------|
| id | number | 主键，自增 |
| title | string | 标题 |
| content | string | 正文 |
| contentHtml | string \| null | HTML 格式内容（可选） |
| chineseChars | number | 汉字字数统计 |
| fontFamily | string | 字体 |
| fontSize | number | 字号 |
| fontColor | string | 字体颜色（#RRGGBB） |
| isBold | boolean | 是否加粗 |
| **isReading** | boolean | 阅读中开关（决定是否进入任务池） |
| **isRequired** | boolean | 必读文章（会被排到今日任务最前面） |
| requiredDays | string | 必读书日期配置（保留字段） |
| useIndependentCheckRate | boolean | 是否使用独立目标打卡率 |
| independentCheckRate | number | 独立目标完成率（0~100） |
| createTime | string | 创建时间（ISO 8601） |
| isLongArticle | boolean | 是否长文章标记 |
| checkInDays | number | 累计打卡天数 |
| completionRate | number | 当前完成率（0~100） |
| lastModified | string | 最后修改时间 |

### Concept（概念）

定义于 [entry/src/main/ets/model/Concept.ets](entry/src/main/ets/model/Concept.ets)

| 字段 | 类型 | 含义 |
|------|------|------|
| id | number | 主键 |
| title | string | 概念标题 |
| category | string | 分类 |
| subject | string | 学科 |
| chapter | string | 章节 |
| content | string | 概念内容 |
| isReading | boolean | 背诵开关 |
| createTime | string | 创建时间 |
| lastModified | string | 最后修改时间 |

### Config（应用配置）

定义于 [entry/src/main/ets/model/Config.ets](entry/src/main/ets/model/Config.ets)

| 字段 | 含义 | 默认值 |
|------|------|--------|
| dailyMinutes | 每日目标阅读分钟数 | 20 |
| targetCheckRate | 目标打卡率（0~100） | 30 |
| keepScreenOn | 是否保持屏幕常亮 | false |
| autoSyncWebDav | 是否自动同步 | false |
| webdavUrl / webdavUsername / webdavPassword | WebDAV 连接信息 | 空 |
| webdavRemotePath | WebDAV 远端路径 | /DailyRead |
| lastSyncTime | 上次同步时间 | 空 |
| yesterdayLongArticleIds | 昨日长文章 ID 列表（防重复） | 空 |
| syncArticlesEnabled / syncConceptsEnabled | 是否同步文章/概念 | true |
| lastResetMonth | 上次重置月份（跨月重置打卡） | 空 |

---

## 🧠 核心业务逻辑：今日任务生成

核心逻辑位于 [DailyTaskService.ets](entry/src/main/ets/service/DailyTaskService.ets) 的 `getOrGenerateTodayTasks()` 方法。

### 算法流程

```
1. 命中缓存？若当日 tasks 已存在 → 直接返回（稳定不变）
2. 从 Config 读取 dailyMinutes 和 targetCheckRate
3. 任务池筛选：
   isReading = true 且 completionRate < effectiveRate
   （effectiveRate：有独立目标率优先用它，否则用全局 targetCheckRate）
4. **必读前置**：将 isRequired=true 的文章先排到结果最前面
5. 计算字数上限：
   maxWordLimit = dailyMinutes × 250 × (1.01 ~ 1.11 随机系数)
6. 长/短文章分类：
   字数 > maxWordLimit × 30% 判定为长文章
7. 分支选取：
   A) 无长文章 → 用短文章随机填满字数上限
   B) 1 篇长文章 → 若它本身 ≤ maxWordLimit 必选，剩余用短文章补
   C) ≥2 篇长文章 → 随机组合长文章（总字数 ≤ maxWordLimit×70%），
      防重复校验：昨日长文章列表作为「黑名单参考」，剩余用短文章补
8. 转换为 DailyTaskItem 列表，持久化到 daily_tasks 表
```

### 防重复机制

- 短文章选取：最多 100 次随机抽取，每次从候选池移除已选项
- 长文章选取：通过 `yesterdayLongArticleIds` 对比昨日与今日列表，最多 10 次尝试避免相同组合
- 若多次尝试仍无法避免重复 → 降级允许重复

---

## ☁️ WebDAV 同步

### 文件格式

与 Windows 端完全兼容，远端文件名 `daily_read_backup_windows.json`：

```json
{
  "version": 1,
  "exportTime": "2026-06-13T10:00:00.000Z",
  "dataType": "daily_read_backup_windows",
  "articles": [
    {
      "id": 1,
      "title": "...",
      "content": "...",
      "contentHtml": "",
      "chineseChars": 123,
      "fontFamily": "default",
      "fontSize": 16,
      "fontColor": "#000000",
      "isBold": false,
      "isReading": true,
      "isRequired": true,
      "requiredDays": "",
      "useIndependentCheckRate": false,
      "independentCheckRate": 0,
      "isLongArticle": false,
      "checkInDays": 0,
      "completionRate": 0,
      "createTime": "2026-06-13T10:00:00.000Z",
      "lastModified": "2026-06-13T10:00:00.000Z"
    }
  ],
  "concepts": [
    {
      "id": 1,
      "title": "...",
      "category": "...",
      "subject": "...",
      "chapter": "...",
      "content": "...",
      "isReading": true,
      "createTime": "...",
      "lastModified": "..."
    }
  ]
}
```

### 合并策略（mergeArticles / mergeConcepts）

- 以 `title` 为唯一键
- 远端有、本地无 → 插入
- 两边都有 → 比较 `lastModified`，远端更新则覆盖
- 本地有、远端无 → 保留不动（不删除）

---

## 🛠 构建与运行

### 环境要求

- **DevEco Studio**（推荐 5.0+）
- HarmonyOS SDK（API 11+）
- Node.js 16+（hvigor 构建工具依赖）

### 构建步骤

1. 用 DevEco Studio 打开本项目
2. 依赖自动同步（oh-package）
3. 连接真机或启动模拟器
4. 点击运行按钮（▶）构建并安装 hap

### 命令行构建

```bash
# 构建
hvigorw assembleHap

# 清理
hvigorw clean
```

---

## 🗄 数据库设计

位于 [AppDatabase.ets](entry/src/main/ets/database/AppDatabase.ets)

| 表名 | 说明 |
|------|------|
| contents | 文章表 |
| concepts | 概念表 |
| acupoints | 穴位表 |
| content_checkins | 打卡记录表 |
| config | 应用配置（单条） |
| daily_tasks | 每日任务（日期维度） |
| daily_task_items | 每日任务条目（文章维度，关联 daily_tasks） |

### 设计要点

- **主键自增**：所有表使用 `INTEGER PRIMARY KEY AUTOINCREMENT`
- **WAL 模式**：`PRAGMA journal_mode=WAL` + `synchronous=FULL` 保证写入持久化，避免数据丢失
- **字段缺失即降级**：导入/下载时，每个字段使用 `|| 默认值` 方式容错，能兼容旧版 JSON 备份
- **自动升级**：`init()` 中按需要执行 ALTER TABLE，保证版本兼容；不会 DROP TABLE

---

## 📱 页面导航

```
首页 (Home)
  ├─ 今日目标（字数、目标率、完成数/总数）
  ├─ 今日任务列表（文章 + 必读标记 + ✓ 打卡完成状态）
  │   ├─ "📖 随机阅读"按钮 → 从**未完成文章**中随机抽取一篇进入阅读页
  │   └─ 点击文章 → 阅读页 (Reader)
  └─ 底栏：文章管理 / 随心阅读 / 背穴位 / 背概念 / 设置

文章管理 (ArticleManage)
  ├─ 新增文章（标题、内容、阅读中、必读复选框）
  ├─ 编辑文章
  ├─ 多选批量删除
  └─ 独立目标率设置

概念设置 (ConceptSettings)
  ├─ 新增概念（标题、分类、学科、章节、内容）
  ├─ 编辑 / 删除
  └─ 关键字筛选

背概念 (ConceptStudy)
  └─ 随机展示 isReading=true 的概念数据，"下一个"切换

背穴位 (AcupointStudy)
  └─ 基于内置 acupoints.json 穴位库随机抽取

设置 (Settings)
  ├─ 每日阅读时间
  ├─ 目标打卡率
  ├─ 坚果云 WebDAV 同步配置指引
  ├─ 测试 WebDAV 连接
  ├─ 上传 / 下载
  └─ 本地 JSON 导入 / 导出
```

---

## ✅ 必读标记机制

- **开关位置**：`ArticleManage.ets` 添加/编辑文章弹窗中，"必读"复选框位于"阅读中"下方
- **列表展示**：文章管理列表中，`isRequired=true` 的文章标题右侧会显示红色五角星 ★
- **任务排序**：`DailyTaskService` 生成今日任务时，必读文章会被优先直接放入任务列表最前端，再进行剩余文章的随机选取

---

## 🔄 备份与导入兼容说明

### 导出

```typescript
BackupService.exportToJSON()
```
- 导出 **所有字段**（含 isRequired、checkInDays、completionRate 等新增字段）
- 版本号：5

### 导入

```typescript
BackupService.importFromJSON(jsonString, clearBeforeImport)
```
- **完全兼容旧版**：所有新增字段都附带默认值（`isRequired=false`、`checkInDays=0` 等），旧版 JSON 缺少字段不会报错
- `clearBeforeImport=true` → 先清空再插入
- `clearBeforeImport=false` → 按 `title` 去重合并，跳过已存在项
- 能识别 `articles` / `articleList` / `contents` 等多种键名

---

## 🔐 权限说明

本应用所使用的权限均声明在 [entry/src/main/module.json5](entry/src/main/module.json5) 的 `requestPermissions` 节点内。

### 清单权限（在 module.json5 中明确声明）

| 权限常量 | 用途说明 | 授权级别 |
|----------|----------|----------|
| `ohos.permission.INTERNET` | 提供 WebDAV 上传/下载、测试连接等网络通信能力 | normal（正常权限，安装时自动授予） |

### 系统默认已开放的能力（无需单独申请）

HarmonyOS 对以下能力在 API 11+ 默认开放，不需要写入 `requestPermissions`：

- **应用内文件读写**（`context.filesDir` / `context.cacheDir`）：用于写入 JSON 导出文件、缓存 WebDAV 下载内容
- **窗口常亮**（`Window.setWindowKeepScreenOn`）：由 Config 中的 `keepScreenOn` 控制
- **关系型数据库（RdbStore）**：SQLite 数据库创建与读写

> 💡 如果需要把导出文件放到外部存储供用户手动查看（如"文档"目录），或访问 `pictures` 等系统相册，
> 则需要额外声明 `ohos.permission.READ_IMAGEVIDEO` / `ohos.permission.READ_PASTEBOARD`
> 以及 `ohos.permission.WRITE_IMAGEVIDEO` 并在运行时调用 `requestPermissionsFromUser` 申请用户授权。
> 当前 DailyRead 的导入/导出功能均走应用私有沙箱路径，不触发用户授权弹窗。

### 权限申请流程

应用未做运行时权限申请（Runtime Permission）逻辑，所有网络能力依赖安装时自动授予的 `ohos.permission.INTERNET`。
首次启动时仅进行数据库初始化与 WebDavSyncService 上下文注入（[EntryAbility.ets](entry/src/main/ets/entryability/EntryAbility.ets)）。

---

## 🧪 测试

- `entry/src/ohosTest/ets/test/Ability.test.ets`：Ability 启动测试
- `entry/src/ohosTest/ets/test/List.test.ets`：列表组件测试
- `entry/src/test/LocalUnit.test.ets`：本地单元测试

在 DevEco Studio 中选择对应 Test 目录 → 右键 **Run Tests**。

---

## 📝 开发规范

| 项目 | 规范 |
|------|------|
| 代码风格 | 2 空格缩进，严格 ArkTS |
| 命名 | `PascalCase` 用于类与接口；`camelCase` 用于方法与变量 |
| 业务层分层 | page → service → repository → database |
| 数据库写入 | 所有表字段修改必须在 `AppDatabase.init()` 中加入对应的 `ALTER TABLE` 升级语句 |
| 时间格式 | 统一 ISO 8601（`new Date().toISOString()`） |
| 中文编码 | JSON 解析前做字符容错，避免中文乱码 |

---

## 🆙 版本更新日志

### v1.5.0 — 2026-06-16

**🐛 Bug 修复：今日阅读列表"已完成"状态显示不正确**

- **问题**：在阅读页完成打卡后点击"←"返回首页，首页任务列表仍显示该文章未完成（图标为 ○ 而非 ✓，底色未变紫），但进入阅读页能看到"已打卡"状态。
- **根因**：
  1. `router.back()` 返回时，Home 页面可能走**缓存恢复**而非重建，`aboutToAppear()` / `loadData()` 不会重新执行
  2. `AppStorage` 的 `dataRefreshSignal` 在 Home 页面不可见或监听不生效
  3. `@State tasks[i].isCheckedIn` 来自 `daily_task_items` 表，但打卡成功后该字段可能尚未被同步更新
- **修复方案**（三层保障）：
  1. **渲染层实时判定**：Home 中 `TaskCard` 的 `isCheckedIn` 改为**直接调用同步方法** `isArticleCheckedIn(articleId, item.isCheckedIn)`，不再依赖异步刷新
  2. **AppStorage 实时同步**：新增 `todayCheckedInIds` 键，格式为 `"2026-06-16|id1,id2,id3"`，Reader 打卡成功后立即写入；Home 用 `@StorageLink` 实时感知并触发重新渲染
  3. **DB 启动同步**：Home `aboutToAppear` 中调用 `syncTodayCheckedInIdsToStorage()`，从 `check_in_records` 表读取今日打卡文章并写入 AppStorage，确保当日首次启动也能正确显示
- **涉及文件**：
  - [Home.ets](entry/src/main/ets/pages/Home.ets) — `@StorageLink('todayCheckedInIds')`、`syncTodayCheckedInIdsToStorage()`、`isArticleCheckedIn()`、TaskCard 渲染改为内联调用
  - [Reader.ets](entry/src/main/ets/pages/Reader.ets) — `handleCheckIn()` 中写入 AppStorage `todayCheckedInIds`

**✨ 新功能：随机阅读按钮**

- **位置**：首页"今日任务"标题行右侧
- **图标**：📖（图书图标）+ 文字"随机阅读"，浅灰胶囊背景
- **行为**：
  1. 筛选今日任务列表中 **isCheckedIn=false** 的文章
  2. `Math.random()` 随机抽取一篇
  3. `router.pushUrl` 跳转到阅读页（Reader）
  4. 如果所有文章都已完成 → Toast 提示 "所有文章都已完成"
- **涉及文件**：
  - [Home.ets](entry/src/main/ets/pages/Home.ets) — 新增 `openRandomUncheckedArticle()` 方法 + build 中插入按钮 Row
  - 新增 `import promptAction from '@ohos.promptAction'`（用于空列表提示）

---

## 📄 License

本项目遵循 MIT License。
