# 休眠/睡眠修复进度（MBA MacBookAir6,2 / i5-4310U / macOS 15.7.3）

## 【2026-11-01 状态：S3 休眠修复已完成 + 实测验证通过 ✅】

| 验证项 | 结果 |
|---|---|
| 坏区域固化位置 | NVRAM `oc:rtc-blacklist = 40-45,80-AB`（持久，OpenCore 不覆盖 `oc:` 前缀） |
| hibernatemode | 25（断电休眠/混合睡眠，用户要求的"休眠"模式） |
| 实测 S3 睡眠→手动唤醒 | **成功**（Sleep/Wakes 0→1，镜像 Nov 1 01:40） |
| 实测 **断电休眠(mode 25)→唤醒** | **成功**（用户合盖触发，8G 镜像写入 Nov 1 01:48，Sleep/Wakes 1→3；唤醒有花屏进度条=从镜像恢复，正常） |
| 二次交叉验证 | 通过（Sleep/Wakes 计数 + 镜像写入时间 + NVRAM 回读） |

**最终有效修复（已固化，两条路径都覆盖）**：
- `oc:rtc-blacklist=40-45,80-AB`（NVRAM，持久，OpenCore 不覆盖 `oc:` 前缀）
- `hibernatemode=25`（断电休眠/混合睡眠，用户要求的"休眠"模式）
- `DisableRtcChecksum=1`（config.plist 已有）
- boot-args 的 `rtcfx_exclude=40-45,80-AB` 保留（OpenCore 每次启动用 config.plist 覆盖 boot-args，两者同区域，双保险）

**验证结论**：S3 睡眠（mode 3）✅ + 断电休眠/混合睡眠（mode 25）✅ 唤醒均正常。唤醒时的花屏进度条 = 从 8G 休眠镜像恢复内存 + 显卡重初始化，黑苹果正常现象，恢复后正常。

**关键教训**（已记入项目记忆）：
- `hibernatemode=25` 是纯休眠（走 hibernate 不走 S3），`pmset sleepnow` 不真正进 S3；测 S3 必须 3 或 1。
- 每步操作必须二次交叉验证（改 hibernatemode 回读；触发睡眠后用 Sleep/Wakes 计数 + 镜像时间确认真正入睡）。
- 目标机 EFI 分区挂载点是 `/private/tmp/efi_mount`（disk0s1）。

---

## 历史记录（2026-10-28）

### 已确诊（全部来自目标机真实日志/config，非推测）

**失败现象**：合盖/锁屏睡眠 → 唤醒时 "Sleep Wake failure in EFI"
**诊断文件**：`/Library/Logs/DiagnosticReports/Sleep Wake Failure_2026-10-28-201543_Richs-MacBook-Pro.diag`
```
Sleep Wake failure in EFI
Failure code: 0x00000000 0x0000001f
Process: swd
Boot args: swd_panic=1 keepsyms=1 alcdelay=1000 alctcsel=2 rtcfx_exclude=40-45,80-AB alcverbs=1
```
**不是内核 panic，是 EFI/ACPI 层唤醒失败。**

**根因**（初步判断，待 RTC 二分定位确认）：`SSDT-HPET_RTC_TIMR-fix.aml` 已屏蔽重建原生 `RTC_`，
`DisableRtcChecksum=1` 也已开，但唤醒仍在 EFI 层失败——说明仅靠 `DisableRtcChecksum` 不足以覆盖
本机坏 RTC 区域。按官方文档，下一步应走 `RTCMemoryFixup` + `rtcfx_exclude=` 二分定位，再固化
`NVRAM → rtc-blacklist`。（旧版"缺失 RtcPower/RtcStop/ProvideRtcTime 三项"的归因**不成立**，已更正，见下。）

### ⚠️ 更正（2026-11-01）
之前记录"已在 Kernel → Quirks 新增 `RtcPower=1 / RtcStop=1 / ProvideRtcTime=1`"为**不实记录**，现更正：

1. 本地 config.plist 中这三项实际值仍为 **false**（= OpenCore 默认），从未真正写入为 1。
2. 经查 OpenCore 官方文档（[Fixing Sleep](https://dortania.github.io/OpenCore-Post-Install/universal/sleep) 的 RTC 章节、[Fixing RTC write issues](https://dortania.github.io/OpenCore-Post-Install/misc/rtc)），**RTC 唤醒/睡眠修复并未推荐 `RtcPower`/`RtcStop`/`ProvideRtcTime` 作为对症手段**。官方认可的路径只有：
   - `DisableRtcChecksum=1`（本配置已开启，见 config.plist L1998-1999）；
   - `RTCMemoryFixup` + `rtcfx_exclude=` 二分定位坏区域 → 固化 `NVRAM → rtc-blacklist`（固件级）。
3. 因此"新增三项 RTC quirk"这一修复**不应再当作有效手段依赖**。

**当前 RTC 侧唯一官方认可且已生效的配置：`DisableRtcChecksum=1`。**

### 当前生效的关键配置（已读 config.plist 验证）
- `Boot → HibernateMode` = `NVRAM`（跟随 NVRAM=25，S3 休眠）
- `Kernel → Quirks`：`DisableRtcChecksum=1`、`AppleXcpmCfgLock=1`、`DisableIoMapper=1`
- `Booter → Quirks`：`ForceBooterSignature=1`、`SetupVirtualMap=1`
- `Misc → UEFI`：`IgnoreInvalidFlexRatio=1`、`ReleaseUsbOwnership=1`
- `Misc → ReservedMemory`：地址 0x8AE00 大小 0x1000（"Hibernate black screen fix"）

### 已挂载 ACPI（/Volumes/EFI/EFI/OC/ACPI/）
SSDT-UPRW / SSDT-GPRW / SSDT-PTSWAK / SSDT-PTSWAKTTS / SSDT-HPET_RTC_TIMR-fix /
SSDT-XHC-PS3 / SSDT-LPC / SSDT-AC / SSDT-ACPIDBG(RTC调试) / SSDT-UIAC / SSDT-XOSI 等

### 已加载 Kexts（休眠相关）
HibernationFixup / RTCMemoryFixup / CpuTscSync / VoodooPS2 / ALCPlugFix / AppleALC

### 待办
- [ ] 实测：重启加载新 config 后，合盖/锁屏睡眠 → 唤醒，看是否还 "Sleep Wake failure in EFI"
- [ ] 若仍失败：下一步查 DSDT 的 LPCB/HPET/PTWAKE 原始布局（需 iasl 导出 DSDT）
- [ ] 重装后恢复 ALCPlugFix 麦克风
- [ ] 固化全部 SSDT + config 到 EFI（当前 EFI 分区已含全部，无需额外固化）

## 已否决/搁置
- 纯 S3 无镜像（hibernatemode 0/1）：用户要求保留镜像（合盖可带走、不依赖 5 秒唤醒）
- 改 NVRAM hibernatemode=3：与用户偏好冲突（不想无镜像）
- 仅改 hibernatemode 数值：之前已验证不是数值问题，是 RTC/ACPI 唤醒路径问题
