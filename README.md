# E7440 黑苹果 EFI 项目

DELL Latitude E7440 的 OpenCore 引导配置，目标系统 **macOS 11.7.10 Big Sur**。

> 本项目已用 git 管理，防止 EFI 配置再次丢失。所有变更走「分支 + 提交」流程，详见 [开发计划](docs/开发计划.md)。

## 项目状态

| 项目 | 状态 |
|------|------|
| 引导器 | OpenCore 1.0.2 |
| 目标系统 | macOS 11.7.10 Big Sur |
| SMBIOS | MacBookPro11,1 |
| 当前进度 | 可进入 Recovery（画面花屏），**尚未进入 Big Sur** |
| 已知阻塞 | ① 花屏 ② 休眠失败（ShutdownCause 5，详见复盘报告） |

## 硬件

- 机型：DELL Latitude E7440
- 平台：Haswell-ULT（4 代酷睿）
- 核显：Intel HD 4400/4600（device-id `0x0412`，ig-platform-id `0x0A260006`）
- 网卡：Intel 无线（AirportItlwm）+ I218-LM 有线（IntelMausi）
- 声卡：ALC（AppleALC，layout-id 12）

## 目录结构

```
.
├── README.md              # 项目说明（本文件）
├── .gitignore
├── EFI/                   # OpenCore EFI 引导（git 管理的核心）
│   ├── BOOT/              # BOOTx64.efi（含 .bak 历史备份）
│   └── OC/
│       ├── config.plist   # OpenCore 主配置
│       ├── OpenCore.efi
│       ├── ACPI/          # SSDT 补丁
│       ├── Drivers/       # HfsPlus / OpenRuntime / OpenCanopy
│       ├── Kexts/         # 内核扩展
│       ├── Tools/         # CleanNvram 等工具
│       └── Resources/     # 图形界面主题资源
└── docs/
    ├── 开发计划.md         # 迭代计划（按优先级）
    ├── 开发进度.md         # 进度跟踪
    └── E7440-休眠问题复盘报告.html   # 休眠问题完整复盘
```

## 当前配置要点

- **boot-args**：`keepsyms=1 alcid=12 -v`（`-v` 为排查花屏临时开启）
- **Booter Quirks**：`EnableWriteUnprotector=true` + `RebuildAppleMemoryMap=false`（二者不可同时为 true）
- **HibernateMode**：`None`（休眠功能已禁用，规避 ShutdownCause 5）
- **已移除**：HibernationFixup / RTCMemoryFixup 等休眠相关 kext（见复盘报告）

## 同步到 TF 卡

从仓库同步 EFI 到 TF 卡 EFI 分区（分区挂载于 `/Volumes/EFI`）：

```bash
rsync -a --delete --exclude 'Microsoft' --exclude '.Spotlight-V100' --exclude '.fseventsd' \
  ./EFI/ /Volumes/EFI/EFI/
```

## 开发规范

- 每次改动前开新分支，完成后提交合并到 `main`
- 提交信息用中文，格式：`类型: 简述`（类型如 `fix` / `feat` / `docs` / `test`）
- 每次改动记录到 [开发进度](docs/开发进度.md)
- 涉及 SMBIOS 序列号等标识，本仓库仅本地使用，勿公开分享

## 已知问题

1. **花屏**：进入 Recovery 后画面异常（核显 framebuffer 待调优）
2. **无法进入 Big Sur**：当前停在 Recovery，系统未完成安装/启动
3. **休眠失败**：hibernatemode 25 触发 ShutdownCause 5 关机，根因待定位

详见 [E7440-休眠问题复盘报告](docs/E7440-休眠问题复盘报告.html)。
