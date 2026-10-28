# E7440 黑苹果 EFI 项目

DELL Latitude E7440 的 OpenCore 引导配置 + 系统侧配套组件，目标系统 **macOS 11.7.10 Big Sur**。

> 本项目用 git 管理，防止 EFI 配置再次丢失。所有变更走「分支 + 提交」流程，详见 [开发计划](docs/开发计划.md)。

## 项目状态

| 项目 | 状态 |
|------|------|
| 引导器 | OpenCore 0.9.1（`OpenCore.efi` 598016 字节） |
| 目标系统 | macOS 11.7.10 Big Sur（系统盘为 USB 外接） |
| SMBIOS | MacBookAir6,2 |
| 引导 | ✅ 正常进入系统 |
| WiFi / 蓝牙 | ✅ AirportItlwm_BS + IntelBluetooth 三件套 |
| 音频输出 | ✅ AppleALC，layout-id 12（ALC292） |
| 麦克风增益 | ✅ ALCPlugFix 压制增益（见「系统侧部署」） |
| 睡眠 | ⚠️ 纯 S3 正常；hibernatemode 25 存在异常 |
| Recovery | ⚠️ 只能看到灰白背景（系统卷 SSV 已损坏，非 EFI 问题） |

## 硬件

- 机型：DELL Latitude E7440
- 平台：Haswell-ULT（4 代酷睿）
- 核显：Intel HD 4400/4600（device-id `0x0412`，ig-platform-id `0x0A260006`）
- 网卡：Intel 无线（AirportItlwm_BS 2.0.0）+ I218-LM 有线（IntelMausi）
- 声卡：Realtek ALC3226（实际 ALC292，vendor `0x10EC0292`）
- 键盘触摸板：VoodooPS2Controller R6
- 电池：SMCBatteryManager

## 目录结构

```
.
├── README.md              # 项目说明 + 安装部署（本文件）
├── .gitignore
├── EFI/                   # OpenCore EFI 引导（烧录到 EFI 分区的内容）
│   ├── BOOT/              # BOOTx64.efi
│   └── OC/
│       ├── config.plist   # OpenCore 主配置
│       ├── OpenCore.efi
│       ├── ACPI/          # SSDT 补丁（12 个启用）
│       ├── Drivers/       # OpenCanopy / OpenHfsPlus / OpenRuntime / ResetNvramEntry
│       ├── Kexts/         # 内核扩展（22 项启用）
│       ├── Tools/         # CleanNvram 等
│       └── Resources/     # 图形界面主题
├── tools/
│   └── ALCPlugFix/        # 系统侧组件：麦克风增益压制
│       ├── ALCPlugFix            # 二进制（Swift，直接对接 ALCUserClientProvider）
│       ├── alc-verb             # 读/写 codec verb 的调试工具
│       ├── config.plist         # 要发送的 verb 列表
│       ├── com.black-dragon74.ALCPlugFix.plist  # LaunchAgent
│       └── install.sh           # 一键安装
└── docs/
    ├── 开发计划.md
    ├── 开发进度.md
    └── E7440-休眠问题复盘报告.html
```

## 安装部署

部署分两部分，**互不依赖，但缺一不可**：

| 部分 | 位置 | 重装系统后 |
|------|------|-----------|
| EFI（引导 + kext + boot-args） | 磁盘 EFI 分区 | 保留（除非抹盘） |
| ALCPlugFix（麦克风增益） | 系统卷 `/usr/local` + `/Library/LaunchAgents` | **丢失，需重新安装** |

### 一、EFI 部署

1. 挂载目标盘的 EFI 分区（E7440 上通常为 `disk0s1`，卷名 `OC`/`EFI`）：

```bash
sudo diskutil mount disk0s1          # 挂载到 /Volumes/OC
```

2. 从仓库同步（源目录末尾的 `/` 不能省）：

```bash
rsync -a --delete --exclude 'Microsoft' --exclude '.Spotlight-V100' --exclude '.fseventsd' \
  ./EFI/ /Volumes/OC/EFI/
```

3. 校验后卸载：

```bash
md5 EFI/OC/config.plist /Volumes/OC/EFI/OC/config.plist
sudo diskutil unmount /Volumes/OC
```

> OpenCore 会在 EFI 分区根目录写 `opencore-YYYY-MM-DD-*.txt` 日志（`Misc > Debug > Target` 开启时）。这些文件不在 `EFI/` 目录内，rsync 不会清理它们。

**boot-args 已固化在 `EFI/OC/config.plist`**，无需在系统里改：

```
swd_panic=1 keepsyms=1 alcdelay=1000 alctcsel=2 rtcfx_exclude=40-45,80-AB alcverbs=1
```

其中 `alcverbs=1` 是 ALCPlugFix 能连上 codec 的**必要条件**，不要删。

### 二、系统侧部署（ALCPlugFix）

**为什么需要**：本机麦克风节点（0x12）的输入放大器默认是最大档，导致很小的声音就爆表。社区的 CodecCommander 在 Big Sur 之后无法使用（保留 `IOAudioFamily` 依赖会加载失败，删掉依赖会在进桌面时 panic），因此改用 ALCPlugFix：登录时发送两条 HDA verb 把增益降到 1 档，唤醒时重发。

**安装**：

```bash
cd tools/ALCPlugFix
sudo sh install.sh
```

脚本做的事：

| 动作 | 目标 |
|------|------|
| 拷贝二进制/配置/调试工具 | `/usr/local/ALCPlugFix/` |
| 拷贝 LaunchAgent | `/Library/LaunchAgents/com.black-dragon74.ALCPlugFix.plist` |
| 统一权限 | `root:wheel`，二进制 755、plist 644 |
| 立即生效 | `launchctl bootout` + `bootstrap`（当前登录会话） |

**验证**（两条都应输出 `0x00000001`）：

```bash
/usr/local/ALCPlugFix/alc-verb -q 0x12 0xb60 0    # 左声道输入增益
/usr/local/ALCPlugFix/alc-verb -q 0x12 0xb50 0    # 右声道输入增益
```

进程确认：

```bash
launchctl list | grep ALCPlugFix
```

**调整增益档位**：编辑 `/usr/local/ALCPlugFix/config.plist` 里两条命令的 `Param`（0 = 最小，1 = 当前值，2/3 更大），然后重启 agent：

```bash
launchctl kickstart -k gui/$(id -u) /Library/LaunchAgents/com.black-dragon74.ALCPlugFix.plist
```

### 三、重装系统后的恢复清单

1. EFI：若未抹盘则无需操作；抹盘后按「一、EFI 部署」重新烧录
2. 确认 `EFI/OC/config.plist` 的 boot-args 含 `alcverbs=1`
3. 安装 ALCPlugFix：`cd tools/ALCPlugFix && sudo sh install.sh`
4. **用该用户登录一次**（LaunchAgent 随登录加载，不登录不会运行）
5. 按上面的验证命令确认读回 `0x00000001`
6. 若音频完全无声：先查 `layout-id` 是否为 12、AppleALC 是否加载

**常见坑**

- LaunchAgent 权限必须是 `root:wheel` + 644。用 `cp` 手工拷贝常留下 `staff` 属组，表现为「登录后没生效」
- ALCPlugFix 是普通用户态程序，**不需要** kext 审批、**不需要**关闭 SIP
- `alc-verb` 只是验证工具，ALCPlugFix 运行时不依赖它

## 当前配置要点

- **boot-args**：见上（含 `alcverbs=1`）
- **Booter Quirks**：`EnableWriteUnprotector=true` + `RebuildAppleMemoryMap=false`
- **HibernateMode**：`NVRAM`
- **ACPI（12 个启用）**：XHC-PS3 / EC-LAPTOP / XOSI / HPET_RTC_TIMR-fix / LPC / PLUG / PNLF / PNOT / SMBUS / ALS0 / ALCfix / ACPIDBG
  - 注意：GPRW 补丁与 SSDT-GPRW 当前**未启用**，与 `docs/开发进度.md` 记录的原始基线不同，排查唤醒问题时需留意
- **Kexts（22 项启用）**：Lilu、VirtualSMC（+SMCBattery/SMCProcessor/SMCSuperIO）、WhateverGreen、AppleALC、AirportItlwm_BS、IntelBluetooth 三件套、VoodooPS2 R6（+Keyboard/Trackpad）、IntelMausi、BrightnessKeys、CpuTscSync、USBPorts_E7440、RTCMemoryFixup、HibernationFixup、SystemProfilerMemoryFixup、CodecCommander

## 开发规范

- 每次改动前开新分支，完成后提交
- 提交信息用中文，格式：`类型: 简述`（`fix` / `feat` / `docs` / `test`）
- 每次改动记录到 [开发进度](docs/开发进度.md)
- 涉及 SMBIOS 序列号等标识，本仓库仅本地使用，勿公开分享
- 当前仓库未配置 remote，推送到 GitHub 前需先 `git remote add`

## 已知问题

1. **hibernatemode 25 异常**：纯 S3 正常，休眠/混合睡眠存在唤醒或关机问题，根因待定位
2. **Recovery 灰白背景**：系统卷 SSV（`Sealed: Broken`）导致，与 EFI 无关，需重装或恢复快照
3. **CodecCommander 无效**：Big Sur 下无法加载，其 SSDT（`SSDT-ALCfix.aml`）当前无 consumer，保留仅为历史兼容

详见 [E7440-休眠问题复盘报告](docs/E7440-休眠问题复盘报告.html)。
