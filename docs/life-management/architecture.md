# 目标、习惯与日常记录功能架构

本文档梳理 FlutterClaw 中“目标管理、习惯养成、日常记录”一体化功能的产品架构与技术架构。该功能定位为本地优先的个人生活管理模块，既可以通过 App UI 直接使用，也可以由 Agent 通过工具调用来创建、查询、更新数据。

## 功能目标

该模块覆盖三个高频生活场景：

- **目标管理**：管理长期或短期目标，拆分里程碑和行动任务，跟踪进度并复盘结果。
- **习惯养成**：创建重复性习惯，打卡、跳过、补记，统计连续天数和完成率。
- **日常记录**：记录不一定有固定周期的生活事件，例如加油、理发、汽车保养、就医、订阅扣费、购物等。

核心原则是降低记录成本。用户不需要先判断信息应该放在哪个模块里，一句“今天加油 43 升，花了 320 元”就应该能被快速记录，并被系统或 Agent 归类为结构化的日常记录。

## 功能架构

### 1. 统一信息模型

目标、习惯、日常记录不应被设计成三个完全割裂的模块，而应共用一套生活管理领域模型，再在不同实体上扩展各自字段。

| 实体 | 作用 | 示例 |
|------|------|------|
| `LifeItem` | 目标、习惯、记录的通用元信息 | 标题、备注、标签、附件、创建时间 |
| `Goal` | 有结果导向的目标 | “三个月减重 5kg”、“今年读 24 本书” |
| `Milestone` | 目标阶段检查点 | “5 月底完成 8 本书” |
| `Task/Plan` | 独立任务/待办型计划，可关联目标或习惯 | “今晚读 30 分钟” |
| `TodoList` | 一组轻量待办的主题容器 | “周末要做的 10 件事” |
| `TodoItem` | 主题下的单条可完成待办 | “整理书桌” |
| `Habit` | 重复性行为定义 | “每天喝水 8 杯”、“每周跑步 3 次” |
| `HabitCheckIn` | 一次习惯打卡事件 | 完成、跳过、数值、心情、备注 |
| `LifeRecord` | 非固定周期的事实记录 | 加油、理发、汽车保养、缴费 |
| `RecordTemplate` | 某类记录的字段模板 | 加油模板、汽车保养模板 |
| `ReminderRule` | 提醒规则 | 时间、重复周期、静默时段 |
| `Review` | 周期复盘结果 | 周复盘、月度用车成本总结 |

通用基础字段建议如下：

```dart
class LifeItem {
  final String id;
  final String type; // goal, habit, record
  final String title;
  final String? note;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
}
```

目标、习惯、计划和记录在此基础上维护各自的领域字段，并通过 `id`、标签、时间和引用关系建立关联。

### 2. 目标、习惯与计划关系

目标采用混合关联模型：目标可以收纳展示习惯、计划和记录，但不物理包含它们。这样既能保持目标页面的聚合体验，也能允许习惯和计划独立存在。

推荐语义边界：

- **目标 `Goal`**：回答“我要成为什么/达成什么”，是结果对象。
- **习惯 `Habit`**：回答“我每天/每周重复做什么”，是重复行为对象。
- **计划 `Task/Plan`**：回答“我接下来具体做什么”，是任务/待办对象。
- **记录 `LifeRecord`**：回答“我实际发生了什么”，是事实事件对象。

轻量待办先用 `TodoList -> TodoItem[]` 表达：`TodoList` 是主题，`TodoItem` 是可勾选的行动项。它不承载复杂项目依赖，也不要求绑定目标；目标接入后再通过 id 建立关联。

推荐关系：

```text
Goal
  -> links Habit[]
  -> links Task[]
  -> links LifeRecord[]
  -> owns Milestone[]
```

只有 `Milestone` 适合作为目标的内部阶段节点。`Habit`、`Task/Plan`、`LifeRecord` 应作为独立实体保存，通过 id 与目标建立关联。一个习惯可以服务多个目标，也可以不属于任何目标。

### 3. 轻量待办主题

轻量待办是 `Task/Plan` 的首版实现，优先覆盖简单清单场景，而不是复杂项目管理。

核心关系：

```text
TodoList
  -> owns TodoItem[]
```

核心能力：

- 创建一个待办主题，例如“周末要做的 10 件事”。
- 在主题下添加多条待办项。
- 待办项支持未完成、已完成、已归档状态。
- 待办项支持可选截止日期，用于 Life 首页展示今日到期和已逾期待办。
- 待办主题可以归档；归档后不再参与今日待办聚合。

当前实现边界：

- 不做任务依赖、优先级、重复任务、子任务和看板。
- 不强制绑定目标；目标接入后通过 id 关联 `TodoList` 或 `TodoItem`。
- 不触发本地通知；如后续需要提醒，应复用 `ReminderRule` 和 life-management reminder service。

推荐状态：

- `TodoListStatus.active`：正常展示。
- `TodoListStatus.archived`：归档隐藏。
- `TodoItemStatus.open`：未完成。
- `TodoItemStatus.completed`：已完成。
- `TodoItemStatus.archived`：归档隐藏。

### 4. 目标管理

核心能力：

- 创建目标，设置目标日期、优先级、状态和可度量指标。
- 将目标拆分为里程碑和任务。
- 支持手动更新进度，也支持从关联习惯打卡或日常记录中自动汇总进度。
- 展示进行中、已逾期、已完成、已归档目标。
- 支持目标复盘，包括总结、阻碍、下一步行动和 Agent 建议。

推荐目标状态：

- `draft`：草稿
- `active`：进行中
- `paused`：暂停
- `completed`：已完成
- `abandoned`：已放弃
- `archived`：已归档

推荐进度模式：

- **手动百分比**：用户直接设置进度。
- **指标型进度**：当前值 / 目标值，例如 `12 / 24 本书`。
- **任务型进度**：按任务完成比例计算。
- **关联数据进度**：从习惯打卡或日常记录聚合，例如跑步次数、学习时长、累计存款。

目标进度应从目标自身字段、关联任务、关联习惯和关联记录中聚合，避免要求习惯或计划必须挂载在目标内部。

### 5. 习惯养成

核心能力：

- 创建习惯，支持每日、每周、每月、指定星期、间隔天数等重复规则。
- 支持不同目标值类型：是否完成、次数、时长、距离、金额或自定义单位。
- 支持从首页、聊天、通知动作或 Agent 命令快速打卡。
- 统计连续打卡、完成率、漏打次数、最佳连续记录。
- 支持跳过原因，避免旅行、生病、计划休息等情况污染习惯统计。

打卡状态建议：

- `completed`：完成
- `partial`：部分完成
- `skipped`：主动跳过
- `missed`：未完成

习惯统计应从不可变的打卡事件计算得出。连续天数、完成率等可以缓存，但不应成为唯一事实来源。

### 6. 日常记录

日常记录是事件型日志，可自由输入，也可套用结构化模板。

首批内置模板建议：

| 模板 | 建议字段 |
|------|----------|
| 加油 | 车辆、里程表、升数、金额、油站、油品 |
| 理发 | 店铺、理发师、金额、发型备注、下次提醒日期 |
| 汽车保养 | 车辆、里程表、保养类型、配件、费用、下次保养日期/里程 |
| 就医 | 医院/诊所、科室、症状、费用、复诊日期 |
| 订阅扣费 | 服务名称、金额、扣费周期、下次扣费日期 |
| 购物 | 物品、金额、商家、保修日期 |

日常记录应支持：

- 快速文本记录
- 结构化表单编辑
- 照片、收据等附件
- 在用户授权后记录位置
- 根据记录生成后续提醒，例如“理发 30 天后提醒”或“保养后 5000 公里提醒”
- 按模板、标签、日期范围、金额、车辆/人物等条件搜索过滤

### 7. 快速捕获体验

捕获层应支持多种输入：

- App 内手动表单。
- 首页或聊天输入框的快速文本。
- 现有语音转文字能力。
- 现有相机和媒体工具，用于拍照、收据、截图。
- 来自 Telegram、Slack、Discord、WhatsApp、Signal、WebChat 等频道的 Agent 消息。

推荐快速捕获流程：

1. 用户输入自然语言、语音或图片备注。
2. 本地解析器或 Agent 提取候选类型、标题、日期、金额、数量、标签和提醒。
3. App 展示可确认的结构化预览。
4. 用户保存、编辑或丢弃。

对于低风险操作，例如“今天喝水打卡完成”，在意图明确时可以允许 Agent 直接保存。对于删除、批量修改、敏感记录创建，应要求用户确认。

### 8. 页面结构

首版建议页面：

- **今日**：今日待办、今日应完成习惯、最近记录、今日提醒、快速创建入口。
- **待办**：待办主题列表、主题详情、待办新增/编辑/完成。
- **目标**：目标列表、里程碑、进度、复盘入口。
- **习惯**：习惯列表、日历热力图、连续天数、完成率。
- **记录**：按时间线展示日常记录，提供筛选和搜索。
- **洞察**：周/月汇总、消费统计、用车成本、目标进展。
- **模板**：管理内置模板和自定义记录模板。

这是一个每天使用的效率界面，视觉上应偏稳定、紧凑、可扫描，避免做成营销式页面。

## 技术架构

### 1. 模块目录

建议新增独立 feature 目录，避免继续膨胀现有核心文件：

```text
lib/features/life_management/
  data/
    life_management_store.dart
    life_management_repository.dart
    life_management_serializers.dart
  domain/
    life_item.dart
    goal.dart
    todo_list.dart
    todo_item.dart
    habit.dart
    habit_check_in.dart
    life_record.dart
    record_template.dart
    reminder_rule.dart
    review.dart
  application/
    goal_service.dart
    habit_service.dart
    record_service.dart
    insight_service.dart
    life_capture_parser.dart
  presentation/
    life_home_screen.dart
    life_todos_screen.dart
    life_todo_list_detail_screen.dart
    life_todo_list_editor_screen.dart
    goals_screen.dart
    habits_screen.dart
    records_screen.dart
    record_editor_screen.dart
    widgets/
  tools/
    life_tools.dart
```

领域模型、应用服务、数据访问、UI 和工具层分开，后续迁移存储或增加同步时不影响上层调用。

### 2. 本地存储

首版建议采用 App 私有目录下的 JSON/JSONL 文件，符合当前项目已有的 JSON 配置和 JSONL 会话存储思路。

推荐路径：

```text
{app_documents}/flutterclaw/life_management/
  goals.json
  habits.json
  habit_checkins.jsonl
  records.jsonl
  templates.json
  todo_lists.json
  todo_items.jsonl
  reviews.jsonl
  attachments/
```

存储策略：

- `goals.json`、`habits.json`、`templates.json`、`todo_lists.json` 存储规模较小、需要整体更新的对象集合。
- `habit_checkins.jsonl`、`records.jsonl`、`todo_items.jsonl`、`reviews.jsonl` 存储追加或可重写的事件/条目集合。
- 附件存储为文件，记录中只保存文件路径、MIME 类型、大小和摘要。
- 每类文件增加 `schemaVersion`，为迁移预留空间。
- 医疗、财务、位置等敏感字段避免写入日志；如后续加密，应放在 repository/store 层以下，避免影响 UI 和应用服务。

如果未来记录量和查询复杂度明显增长，可以将 repository 底层迁移到 SQLite/Drift。领域服务和工具接口不应依赖具体存储实现。

### 3. Riverpod 接入

建议为仓储和应用服务增加独立 provider 文件，例如：

```dart
final lifeManagementRepositoryProvider = Provider<LifeManagementRepository>((ref) {
  return LifeManagementRepository(/* app documents path */);
});

final goalServiceProvider = Provider<GoalService>((ref) {
  return GoalService(ref.watch(lifeManagementRepositoryProvider));
});

final habitServiceProvider = Provider<HabitService>((ref) {
  return HabitService(ref.watch(lifeManagementRepositoryProvider));
});

final recordServiceProvider = Provider<RecordService>((ref) {
  return RecordService(ref.watch(lifeManagementRepositoryProvider));
});
```

`lib/core/app_providers.dart` 是当前项目的集中 wiring 文件，但新功能应尽量把 provider 定义放在 feature 内部，再在必要位置导出或注册，降低主 wiring 文件继续变大的风险。

### 4. Agent 工具接入

该功能应暴露为 Agent 工具，方便用户通过自然语言完成记录和查询。

建议工具：

| 工具 | 作用 |
|------|------|
| `life_goal_create` | 创建目标，可附带里程碑和目标指标 |
| `life_goal_update` | 更新目标状态、进度、标题、备注或目标日期 |
| `life_goal_list` | 按状态、标签、到期时间或关键词查询目标 |
| `life_habit_create` | 创建习惯，包含重复规则和提醒设置 |
| `life_habit_checkin` | 完成、跳过或部分完成一次习惯打卡 |
| `life_habit_stats` | 查询连续天数、完成率和最近历史 |
| `life_record_create` | 创建结构化日常记录 |
| `life_record_search` | 按模板、关键词、标签、日期、金额查询记录 |
| `life_capture_parse` | 将自然语言转换为待确认的目标/习惯/记录 payload |
| `life_review_generate` | 基于本地数据生成周报或月报 |

工具层只负责参数校验、权限判断和调用应用服务，不应直接读写文件。

### 5. 提醒与调度

复用项目已有能力：

- `NotificationService`：发送本地提醒。
- `CronService`：执行周期性检查和复盘提醒。
- 现有 `schedule_reminder` 设备工具可供 Agent 使用，但 life-management 内部提醒应由该模块自己的服务管理，这样用户才能在 App 里查看和编辑。

提醒示例：

- 每天 21:00 提醒习惯打卡。
- 理发 30 天后提醒。
- 汽车保养到期日提醒。
- 每周日晚生成周复盘。

基于里程的汽车保养提醒需要用户持续记录里程表，或后续增加车辆档案服务。首版优先实现日期型提醒。

### 6. 洞察与派生数据

洞察结果应从事件和实体中派生，必要时缓存，但必须可重新计算。

首批洞察：

- 目标完成率和逾期目标。
- 习惯连续天数、完成率、漏打趋势。
- 每月各类记录数量和金额。
- 用车相关费用汇总。
- 加油金额、升数、里程趋势。
- 汽车保养间隔预测。
- 存在后续日期但未设置提醒的记录。

### 7. 导入、导出与备份

仓储层应预留导出能力：

- 完整 JSON 备份。
- 日常记录 CSV 导出。
- 周/月复盘 Markdown 导出。

如果未来支持同步，数据模型应提前预留：

- `updatedAt`
- `deletedAt`
- `deviceId`
- `syncVersion`

首版保持完全离线可用，不依赖云端。

## 数据流

### UI 写入流程

```text
Screen/Form
  -> Application Service
  -> Repository
  -> Local Store
  -> Riverpod state invalidation
  -> Updated UI
```

### Agent 写入流程

```text
Channel or Chat
  -> AgentLoop
  -> ToolRegistry
  -> Life Tool
  -> Application Service
  -> Repository
  -> Local Store
  -> Optional notification/reminder update
```

### 快速捕获流程

```text
自然语言 / 语音 / 图片备注
  -> Capture Parser
  -> Proposed Structured Payload
  -> 用户确认或直接保存
  -> Goal / Habit / Record Service
```

## 隐私与安全

该模块可能包含健康、财务、位置、家庭等敏感信息，实现时应遵循：

- 默认本地存储。
- 除非用户明确要求 AI 分析或语义解析，否则不把原始记录发送给 LLM。
- 日志中避免输出敏感字段。
- 删除和批量修改需要确认。
- 归档和删除分开。
- 为模板预留隐私等级字段，便于后续做加密存储或 LLM 脱敏。

## MVP 范围

首个可用版本建议包含：

- 本地 JSON/JSONL 仓储。
- 目标、里程碑和手动进度。
- 习惯重复规则、提醒和打卡。
- 加油、理发、汽车保养三个内置日常记录模板。
- 今日、目标、习惯、记录四个核心页面。
- 基础搜索和日期筛选。
- Agent 工具支持创建、查询、打卡、搜索。
- 日期型提醒。
- 周复盘生成。

首版暂不包含：

- 云同步。
- 多人协作。
- OCR 票据识别。
- 基于里程阈值的自动后台检测。
- 高级分析仪表盘。
- 加密数据库迁移。

## 实施阶段

### Phase 1: 领域模型与存储

- 新增领域模型和序列化逻辑。
- 新增本地 repository 和 schema version。
- 为模型序列化、仓储读写增加单元测试。
- 初始化内置记录模板。

### Phase 2: 核心 UI

- 新增今日、目标、习惯、记录页面。
- 实现创建和编辑流程。
- 实现快捷习惯打卡。
- 实现记录时间线和基础筛选。

### Phase 3: 工具与 Agent 捕获

- 在 `toolRegistryProvider` 中注册 life-management 工具。
- 实现自然语言捕获解析和可确认 payload。
- 支持从聊天和外部频道创建记录、查询目标、完成打卡。

### Phase 4: 提醒与复盘

- 接入本地通知，支持日期型提醒。
- 新增周复盘生成与复盘历史。
- 新增目标、习惯、记录类别的洞察卡片。

### Phase 5: 强化与扩展

- 增加导入导出。
- 增加迁移测试。
- 增加隐私控制和日志脱敏。
- 评估在数据量增长后是否迁移到 SQLite/Drift。

## 待决策问题

- life-management 数据是否纳入现有 agent workspace 备份，还是作为独立用户数据导出。
- 快速捕获是否始终需要用户确认，还是允许对低风险类别启用自动保存。
- 习惯重复规则采用轻量自定义模型，还是采用完整 RFC 5545 recurrence 模型。
- 未来同步层应设计为通用同步能力，还是该功能自己的专用同步。
