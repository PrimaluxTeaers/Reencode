# Reencode 1.6.0 — Windows x86-64

## 中文

安装包命名：`Reencode-WindowsX86-64`

Windows 1.6 还没有构建。这一轮只发布 Android arm64-v8a；Windows 版按 1.6 口径写好说明，正式构建另开工。当前仓库没有 `windows/` runner，Linux 环境不能产出 exe。

已确认的 Windows 口径：

- 只支持 Windows 10 / 11 x64。
- 转码必须在可见的前台窗口里跑；关掉窗口或最小化到托盘不保证继续。Windows 没有 Android 那种前台服务，后台任务不能当成常驻。
- 处理器识别只算物理核和可用逻辑线程，不显示频率，不把能效核算成额外性能核。
- Intel 显示 Intel 与核心数；AMD 显示 AMD 与核心数，SMT 计入逻辑线程；NVIDIA / AMD 显卡单独成页，不混成通用显卡名。
- 硬件编码器按厂商检测：NVENC、AMF、Quick Sync 各自标出。检测不到标红并留在原位置；型号识别不到标黑并写“未知”；启用前再提示一次。
- 编码线程可选择，支持 Intel 超线程；AMD SMT 按逻辑线程计入。
- 快捷键面板独立入口，可改键；默认参考常见转码软件的播放、队列、开始、取消键位。
- GPU 加速在 Windows 作为正常选项；只检测对应硬件能力，不锁具体芯片型号。
- 视频多轨：只处理第一条视频流和全部音频流；字幕、附件和多视频轨不复制。

## English

Installer name: `Reencode-WindowsX86-64`

The Windows 1.6 build does not exist yet. This round ships Android arm64-v8a only; the Windows documentation is written for 1.6, and the actual build starts separately. The repository has no `windows/` runner, and a Linux machine cannot produce an exe.

Confirmed Windows behaviour:

- Windows 10 / 11 x64 only.
- Conversion must run in a visible foreground window; closing the window or minimizing to the tray does not guarantee progress. Windows has no Android-style foreground service, so background work is not a resident mode.
- Processor detection counts physical cores and available logical threads, does not show clock speed, and does not count efficiency cores as extra performance cores.
- Intel shows Intel and its core count; AMD shows AMD and its core count with SMT counted as logical threads; NVIDIA / AMD GPUs get separate pages instead of one generic GPU name.
- Hardware encoders are detected per vendor: NVENC, AMF and Quick Sync are listed individually. A missing encoder is marked red in place; an unreadable model is marked black as "Unknown", with one more warning before enabling.
- Encoding threads are selectable, including Intel Hyper-Threading; AMD SMT counts logical threads.
- A separate shortcut panel allows rebinding; defaults follow common transcoding software for play, queue, start and cancel.
- GPU acceleration is a normal Windows option; only the matching hardware capability is detected, without pinning a specific chip model.
- Multiple video tracks: only the first video stream and all audio streams are processed; subtitles, attachments and extra video tracks are not copied.
