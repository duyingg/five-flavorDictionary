# 五味字典（Five-Flavor Dictionary）

五味字典是一款以手机端为主要使用场景的离线中文单字典应用，提供单字查询、拼音与部首索引、笔顺展示、多音字学习、诗词与传统文化内容，并支持导入和切换皮肤。

隐私政策：[在线阅读](https://www.duyingg.com/Five-Flavor%20Dictionary/privacy) · [网页源码](docs/privacy/index.html)

## 主要功能

- 离线单字查询与简繁对应
- 拼音、部首、笔画等索引
- 汉字笔顺动画
- 多音字闯关与学习
- 诗词、百家姓等传统文化内容
- 可导入的 `.hanzi-skin` 皮肤包

## 开发环境

依赖优先使用 `D:\ChatGPT\dependence`。当前共享语料、网页缓存和项目编译缓存已集中存放，工作区原路径通过目录联接或文件硬链接兼容现有工具。迁移清单与保留边界见 [依赖管理说明](docs/依赖管理与迁移_2026-10-24.md)。

```powershell
# 只查看依赖路径状态，不迁移、不构建
.\tool\use-shared-dependencies.ps1
# 首次迁移，或在已存在共享依赖的机器上恢复兼容路径
.\tool\use-shared-dependencies.ps1 -Apply
```

- Flutter 3.47 或兼容版本
- JDK 21（Android 构筑脚本会自动查找兼容的 JDK 17–24）
- Android SDK 与 Build-Tools 35
- Git LFS

克隆后先取得 LFS 数据并安装依赖：

```powershell
git lfs install
git lfs pull
flutter pub get --enforce-lockfile
```

词语或成语源数据更新后，重新生成应用使用的紧凑索引：

```powershell
dart run tool/import_words.dart
```

运行检查：

```powershell
.\build-apk.ps1 -ValidateOnly
```

构筑本地测试 APK：

```powershell
.\build-apk.ps1
```

每次成功构筑都会自动递增 `pubspec.yaml` 中的构筑号，例如
`1.0.2+3` 会变为 `1.0.2+4`；构筑失败时会自动恢复原版本。需要同时提升
公开版本时可使用 `-VersionIncrement patch`、`minor` 或 `major`：

```powershell
.\build-apk.ps1 -VersionIncrement patch
```

默认生成通用 APK；如需减小单个安装包，可使用 `-Mode split` 按 ABI 分包，
但必须根据设备架构分发对应文件。当前最低支持 Android 7.0。

未配置发布密钥时，APK 使用调试签名，只适合本地安装。公开发布前请配置私有发布密钥并执行：

```powershell
.\build-apk.ps1 -RequireReleaseSigning
```

## 数据与许可证

应用使用的开源字典、诗词、字形和简繁转换数据保留在仓库中。详细来源与许可证位置见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。大于 GitHub 普通文件限制的数据通过 Git LFS 管理。

## 许可证

五味字典自身代码采用 [MIT License](LICENSE)，版权所有 © 2026 duyingg。第三方数据和资源继续遵循各自的原始许可证。
