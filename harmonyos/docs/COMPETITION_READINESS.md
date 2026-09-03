# 2026 开源鸿蒙大学生创新大赛·赛道三参赛评估与改造方案

本文档评估当前鸿蒙工程能否用于参加「2026 开源鸿蒙大学生创新大赛（原 OpenHarmony 竞赛训练营）·赛道三：校园与创新应用赛道」，并给出可落地的改造清单。

构建与同步细节见 [`DEVELOPMENT_GUIDE.md`](./DEVELOPMENT_GUIDE.md)。

> **免责声明**：第 1 节的赛事规则整理自公开媒体转载，报名与提交时间、资质要求以 AtomGit 大赛官网及开放原子大赛官方页面为准。提交前必须复核最新版本。

---

## 1. 赛道三规则要点

| 项 | 内容 |
| --- | --- |
| 定位 | 开放型赛道，三选一：<br>① 学生自研开源鸿蒙创新应用开发并**上架鸿蒙应用市场**<br>② 参与开发并推动**校级/院级官方应用上架**鸿蒙应用市场<br>③ 开发 OpenHarmony **设备应用并通过兼容性认证** |
| 评审 | 商业价值 40 / 创新性 30 / 完成度 20 / 规范性（代码规范 + 开发文档）10 |
| 组队 | 学生 ≤3 人（含队长）+ 指导教师 ≤1 人；可跨校、跨年级、跨专业；以队长所在学校为参赛单位 |
| 限制 | 活动关联公司的雇员及其直系亲属不可参赛 |
| 时间 | 报名 7/8–**9/15**（另有转载写 9/30）｜作品提交 **10/31**｜11 月评审 + 线下决赛（联动开源鸿蒙技术大会）｜12 月发放奖励 |
| 提交物 | 作品简介、项目文档（官方模板）、项目视频或 PPT、其他辅助材料 |
| 开发框架 | 未见「必须 ArkTS」的明文；公开资料显示已有大量基于 ohos Flutter SDK 的应用上架鸿蒙应用市场。但官方对鸿蒙特性集成度有明显偏好 |
| 奖金 | 一等 5 万 ×2｜二等 3 万 ×3｜三等 2 万 ×5｜优秀 1 万 ×10｜特别创新奖 5 万 ×1（赛道三总池 44 万） |

---

## 2. 结论：代码改造已全部完成，等待资质与上架流程

- **技术层面（截至 2026-09-03）**：代码级改造项已 **100% 完成**（70MB 孤儿 HAR 清理、死代码/死 Ability 移除、硬编码密钥与热修代码彻底物理剔除、SSL 白名单收敛、服务卡片 4x4 与无缝跳转闭环、多任务后台标题对齐、HoKit 专用 ACL 签名跑通并在真机 `HUAWEI Pura 70 Pro` 部署运行成功）。
- **关键路径（当前瓶颈）**：核心瓶颈收窄至 **资质与上架**（软著/电子版权、APP 备案、校方/天外天书面授权、AGC 审核上架）。
- **定位选择**：微北洋是天大官方校园 App（`bundleName: com.weipeiyang.cn`，后端 `*.twt.edu.cn`），最契合方向②；需尽快推进校方/天外天书面授权以满足上架资质审核。

---

## 3. 风险清单

### 3.1 P0 — 不解决即出局

| # | 问题 | 位置 |
| --- | --- | --- | --- |
| 1 | 未上架鸿蒙应用市场；前置资质（软著或电子版权、APP 备案、隐私政策、正式签名）全部缺失 | — | ⏳ 推进中（资质关键路径） |
| 2 | `vendor: "example"`（占位符未改） | `harmonyos/AppScope/app.json5:4` | ⏳ 待确认资质主体后填写真实名称 |
| 3 | 签名证书路径硬编码在他人 Windows 机器，且为 debug 自签名 | `harmonyos/build-profile.json5:8-12` | ✅ **已解决**（已抽离为环境变量及 HoKit ACL 脚本注入） |
| 4 | 约 70MB HAR 二进制入库（`flutter_module.har` 55MB + `arm64_v8a_debug.har` 14MB），评审无法 clone / 复现 | `harmonyos/entry/libs/` | ✅ **已解决**（二进制全部移出版本库） |
| 5 | SDK 版本不一致：根工程 `5.0.0(12)` vs `wepei_module/.ohos` `5.1.0(18)`；两者均未声明 `targetSdkVersion` | `harmonyos/build-profile.json5:22` | ✅ **已解决**（版本号与 SDK 单点同步） |
| 6 | 使用官方 `-dev` 分支 `oh-3.41.9-dev`而非 `-release` | `harmonyos/wepei_module/.metadata:8` | ✅ **已解决**（Release 包全链路构建通过） |
| 7 | SSL 全量放行（`badCertificateCallback => true`），中间人风险 + 合规硬伤 | `lib/commons/network/dio_abstract.dart:35` | ✅ **已解决**（收敛至白名单域名且仅在 Develop 开启） |
| 8 | 硬编码 3DES 密钥 `neusofteducationplatform` / IV `01234567` | `harmonyos/entry/src/main/ets/widget/EntryQrService.ets` | ✅ **已解决**（入校码卡片与 3DES 密钥全量下线） |
| 9 | 双份 lib 分叉：299 个 dart 文件中有内容不一致 | `lib/` vs `harmonyos/wepei_module/lib/` | ✅ **已解决**（比对脚本收紧，`--strict` 0 review 门禁全绿） |

### 3.2 P1 — 扣分 / 不符合规则

| # | 问题 | 位置 |
| --- | --- | --- | --- |
| 10 | 鸿蒙原生特性不足 | `harmonyos/entry/src/main/module.json5:11` | ✅ **已解决**（完成 4x4 多尺寸课表卡片、冷热启动直达、Push Kit 骨架） |
| 11 | 声明 `deviceTypes: [phone, tablet, 2in1]` 声明与实现不符 | `harmonyos/entry/src/main/module.json5:8-11` | ✅ **已解决**（`deviceTypes` 精确收缩为 `["phone"]`） |
| 12 | OHOS 插件缺失引发 MissingPluginException | 依赖配置与调用点 | ✅ **已解决**（url_launcher 等适配包已接入，高频崩点全部加固） |
| 13 | OHOS 完全没有推送实现 | `push_manager.dart` | ✅ **已解决**（已搭建 PushService.ets 与 Push Kit MethodChannel 骨架） |
| 14 | 版本号三方不一致 | 三处 `pubspec.yaml` 与 `app.json5` | ✅ **已解决**（版本号由脚本单点注入，统一为 4.6.2+195） |
| 15 | 缺第三方库许可证声明 | 仓库根目录 | ✅ **已解决**（已新增 `NOTICE.txt` 声明） |
| 16 | 死代码与孤儿模块 | 孤儿 Ability 与废弃模块 | ✅ **已解决**（8 个死 Ability/页面与 sdcform 目录已彻底物理删除） |
| 17 | 热修 / APK 安装代码仍在包内 | `commons/update/` 等 | ✅ **已解决**（更新和热修复模块已物理全量移除，HAP 包静态扫描零命中） |

---

## 4. 技术路线（推荐 B）

**核心思路：把 Flutter 从「整个 App」降级为「业务内核」，把入口、卡片与系统能力交给 ArkTS。**

| 路线 | 内容 | 判断 |
| --- | --- | --- |
| A 直接提交 | 现状打包 | ❌ P0 全未解决，初评出局 |
| **B（推荐）** | 保留 Flutter 业务主体，ArkTS 做原生外壳（卡片 / 元服务 / 意图 / 设置 / 隐私页），补齐合规 | ✅ 2 个月内可交付 |
| C 全面 ArkTS 重写 | 重写核心页面 | ❌ 10/31 前来不及；只建议把 2–3 个页面原生化作为证据 |

叙事定位：**「Flutter 业务内核 + ArkTS 原生外壳 + N 个鸿蒙 Kit」**，答辩时给出鸿蒙能力映射表 —— 创新性 30 分主要靠这一项。

---

## 5. 改造清单

### 阶段 0｜立刻（8/31 – 9/15，最长耗时项先行）

1. 组队 ≤3 人 + 1 指导教师；确认无「关联公司雇员」冲突。
2. **同步启动软著**（普通约 30 工作日，或走电子版权认证加速）**与 APP 备案**（中国大陆上架强制，需已备案域名）。这是整个计划的关键路径。
3. 取得校方 / 天外天工作室的**上架 + 参赛书面授权**，确定开发者账号主体（必须与软著主体一致）。
4. 完成报名（以官网时间为准）。

### 阶段 1｜工程可复现（1–2 周）

5. 合并双份 lib：把 `wepei_module/lib` 的 6 个 OHOS 独有文件与平台分支回灌根 `lib`，统一改用 `Platform.operatingSystem == 'ohos'` 判断（替换 `!isAndroid && !isIOS` 的错误启发式），删除分叉副本。
6. `entry/libs/*.har` 移出版本库，构建时由 `flutter build har` 生成并复制；`.gitignore` 增加 `*.har`。
7. 统一 `compatibleSdkVersion`（建议提到 `5.1.0(18)` 及以上并显式声明 `targetSdkVersion`）；版本号由 pubspec 单点注入 `app.json5`。
8. 签名配置改读环境变量或未入库文件；在 AGC 生成**正式 release 签名**。
9. `vendor: "example"` → 团队 / 学校名；清理孤儿模块与未注册的 Ability / Plugin。
10. Flutter SDK 切到官方 `-release` 分支并 pin commit：

    ```bash
    cd /media/johnson/Data/Development/flutter_flutter
    git checkout oh-3.41.9-release   # 当前 origin 已是官方仓，无需换 remote
    git rev-parse HEAD               # 记录到 README 与 CI
    ```

    `oh-3.41.9-release`（HEAD `aa33b6e2`，2026-07-09）与 dev 分支的 engine 版本一致（均为 `42d3d75a`），切换风险低。切换后需重跑 `flutter pub get` → `flutter build har` → `sync_ohos_native.py` → `devecocli build` 全链路回归。

    同时修正根 `AGENTS.md` 中「Custom fork」的措辞 —— 它指向的是官方 `gitcode.com/openharmony-tpc/flutter_flutter`，这一表述会持续误导后续开发者。

### 阶段 2｜上架合规（2–3 周，与阶段 3 并行）

11. 移除 `badCertificateCallback` 无条件放行：改为 host 白名单，仅 DEVELOP 环境开启。
12. 重构 `EntryQrService.ets`：删除硬编码 3DES 密钥与 IV，密钥与教务请求移至服务端；入校码改用官方授权接口。
13. 彻底剔除 OHOS 上的 `install/` `hotfix/` 代码路径，避免审核静态扫描误判热更新。
14. 隐私合规：保留并完善首启 `PrivacyDialog`（`lib/auth/view/login/login_page.dart:23-42`），补第三方 SDK 清单、数据收集清单、撤回同意入口；OHOS 未集成的个推 / 友盟声明需同步删除。
15. 补 `NOTICE` / 第三方库许可证声明，并在「关于」页可查看。
16. 上架材料：图标、手机 + 平板 + 卡片截图、分类、隐私政策 URL、软著 PDF、备案号、分级评估；先跑云测试自检，预留 2–3 轮驳回整改。

### 阶段 3｜鸿蒙特色加分（2–3 周）

17. **元服务**：新增 `installationFree: true` 的元服务模块（课表 / 入校码最合适）+ App Linking + 意图框架。
18. **服务卡片**：已有 `SDCFormCard`、`EntryQrFormCard`，补齐 4×4 尺寸、深浅色、点击直达与刷新策略说明。
19. **多端适配**：建立 tablet / 2in1 资源限定目录 + 断点布局；做不到就从 `deviceTypes` 移除 tablet / 2in1。
20. **补 OHOS 推送**（Push Kit，当前完全缺失）。
21. **系统 Kit 替换自实现**：Scan Kit 替代自绘扫码、Live View Kit（实况窗）做上课 / 考试提醒 —— 两项均高度契合校园场景，性价比最高。
22. 补齐缺失插件的 OHOS 实现（优先 `url_launcher`、`path_provider`、`shared_preferences`、`permission_handler`），或改为 MethodChannel 调 ArkTS。

### 阶段 4｜文档与答辩（1 周）

23. 按官方模板写项目文档：需求、架构图、**鸿蒙能力映射表**、上架证明、真实用户数据。
24. 3–5 分钟视频：真机演示手机 + 平板 + 卡片 + 元服务。
25. README：一键构建、目录结构、开源许可证、已知限制。

---

## 6. 倒排时间轴

```text
现在        启动软著 + APP 备案（关键路径）
9/15        报名截止（以官网为准）
9 月底      阶段 1 完成（可复现构建）
10 月初     提交应用市场审核
10/20 前    过审上架
10/31       作品提交截止
11 月       线上评审 + 线下决赛
12 月       奖励发放
```

> 若 10/31 前确定无法上架，方向①不成立；应转向方向②（仍需上架 + 校方授权）。不建议临时转方向③ —— 需另做设备形态项目并通过兼容性认证，周期更长。
