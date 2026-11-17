# Reencode 1.6.0 — Windows x86-64

## 中文

安装包命名：`Reencode-WindowsX86-64`

Windows 1.6 由 GitHub Actions 的 `windows-latest` runner 构建，产物是 `Reencode-WindowsX86-64-1.6.0.zip`，解压后运行目录里的 `reencode.exe`。真实 Windows 10 / 11 x64 的图形、文件对话框和硬件编码仍需在本地机器上复核；Linux 环境不能直接产出 exe。

已确认的 Windows 口径：

- 只支持 Windows 10 / 11 x64。
- 转码在可见的前台窗口里跑；关掉窗口不保证继续。Windows 没有 Android 那种前台服务，后台任务不能当成常驻。
- 处理器识别只算物理核和可用逻辑线程，不显示频率，不把能效核算成额外性能核。
- 硬件编码器只检测 NVIDIA NVENC 和 AMD AMF；检测不到就留在原位置并标红，型号读不到写“未知”。Quick Sync 没有接入，不在界面里承诺。
- 编码线程可选择，支持 Intel 超线程；AMD SMT 按逻辑线程计入。
- 快捷键面板是只读参考页，列出常见转码软件的播放、队列、开始、取消键位；当前版本不支持改键。
- GPU 编码是实验路径；硬件编码失败时删除半成品并回退 CPU，CPU 路径始终可用。
- AV1 只有 `libaom-av1` 软件编码，没有 AV1 硬件编码。
- 插帧入口已删除，144fps 只补重复帧或丢帧；Windows 端也不做插帧。
- 视频多轨：只处理第一条视频流和全部音频流；字幕、附件和多视频轨不复制。

## English

Installer name: `Reencode-WindowsX86-64`

The Windows 1.6 build is produced on GitHub Actions' `windows-latest` runner as `Reencode-WindowsX86-64-1.6.0.zip`; unzip it and run `reencode.exe` from the release folder. Real Windows 10 / 11 x64 graphics, file dialogs and hardware encoding still need a local pass; a Linux machine cannot produce the exe directly.

Confirmed Windows behaviour:

- Windows 10 / 11 x64 only.
- Conversion runs in a visible foreground window; closing it does not guarantee progress. Windows has no Android-style foreground service, so background work is not a resident mode.
- Processor detection counts physical cores and available logical threads, does not show clock speed, and does not count efficiency cores as extra performance cores.
- Only NVIDIA NVENC and AMD AMF are probed. A missing encoder stays in place and is marked red; an unreadable model is shown as "Unknown". Quick Sync is not wired and is not promised in the UI.
- Encoding threads are selectable, including Intel Hyper-Threading; AMD SMT counts logical threads.
- The shortcut panel is a read-only reference page listing common play, queue, start and cancel keys; rebinding is not supported in this build.
- GPU encoding is experimental; a failed hardware job deletes the partial output and falls back to the CPU. The CPU path is always available.
- AV1 is software-only through `libaom-av1`; there is no AV1 hardware encoder.
- The frame-interpolation entry is gone; 144 fps only duplicates or drops frames, and the Windows build does not interpolate either.
- Multiple video tracks: only the first video stream and all audio streams are processed; subtitles, attachments and extra video tracks are not copied.
