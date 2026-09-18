# dsh-desktop-launcher

一键启动 [DeepSeek Harness](https://github.com/deepseek-ai/DeepSeek-Harness)（`dsh`）Web UI 的 Windows 小工具：
双击一个快捷方式，自动打开 PowerShell 并运行 `npx @deepseek-ai/dsh web`，浏览器直接进入界面。

> **One-click launcher for the DeepSeek Harness (DSH) Web UI on Windows.**
> Double-click a shortcut → a PowerShell window opens and runs
> `npx @deepseek-ai/dsh web`. See [English](#english) below.

---

## 特点

- **双击即用** —— 不用每次手敲 `npx` 命令，也不用记端口
- **不闪黑框** —— 用 VBS 静默桥启动，只看到 PowerShell 窗口
- **不会重复起服务** —— 检测到端口已在监听时，直接打开已有界面
- **自动生成图标** —— 内置 PNG → 多尺寸 `.ico` 转换器（含去白边）
- **出问题有日志** —— 安装与图标修复都会写日志文件，便于排查
- **纯本机运行** —— 不联网、不上传任何数据，只用系统自带的 .NET / Windows Script Host

## 环境要求

| 项 | 要求 |
|---|---|
| 系统 | Windows 10 / 11（PowerShell 5.1 即可，无需装 PowerShell 7） |
| Node.js | 已安装，且 `npx` 在 `PATH` 中（[下载](https://nodejs.org)） |
| 权限 | 普通用户即可；写桌面失败时可右键"以管理员身份运行" |

## 快速开始

1. 下载或克隆本仓库。
2. 双击 **`scripts\创建快捷方式.bat`**。
   它会在**桌面**和**开始菜单**创建快捷方式「DSH 快速启动」，做完自动关闭窗口。
3. 之后双击桌面上的「DSH 快速启动」即可打开 DSH。

如果第 2 步不成功，右键该 bat 选 **以管理员身份运行**再跑一次；
结果会记录在同目录的 `Install-Log.txt` 里。

> 这个 bat **文件名是中文，内容却是纯 ASCII**。这不是随意约定：中文控制台
> 代码页是 936（GBK），`.bat` **内容**里若出现 UTF-8 中文，cmd.exe 会读坏
> 引号配对，脚本在第一行静默中止。文件名不受影响。

## 想直接用命令行

```bat
scripts\launch.bat              :: 默认端口 3080
scripts\launch.bat --port 8080  :: 换端口
```

`launch.bat` 会打开一个 PowerShell 窗口（`-NoExit`），在里面执行：

```
npx @deepseek-ai/dsh web --port <PORT> --host 127.0.0.1
```

> `--host` 固定为 `127.0.0.1`，只监听本机回环。DSH 自身明确拒绝 `0.0.0.0`，
> 因为那会把远程代码执行暴露到局域网。

## 常用操作

| 我想…… | 怎么做 |
|---|---|
| 创建／重装快捷方式 | 双击 `scripts\创建快捷方式.bat` |
| 换端口 | `launch.bat --port 8080`，或改 bat 里的 `set PORT=` |
| 停掉 DSH | 在那个 PowerShell 窗口按 `Ctrl + C`，或直接关窗口 |
| 换图标 | 见下方"自定义图标" |

## 自定义图标

把你的图片放到 `scripts/` 下，命名覆盖 `icon-source.png`，然后：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Install-Shortcut.ps1 -StartMenu
```

或直接指定图片路径：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Install-Shortcut.ps1 -IconSource "C:\你的图.png" -StartMenu
```

对图片的建议：

- 正方形，512×512 以上（脚本会生成 16/24/32/48/64/128/256 七种尺寸）
- **带透明通道的 PNG 效果最好**，否则深色任务栏下会出现白底方块
- 若原图白底的边缘发灰，脚本会自动"去白边"；万一误伤了主体的白色部分，
  加 `-NoDeFringe` 关掉即可
- 想换掉第三方素材？仓库自带一个**代码绘制**的备用图标：用你自己的图覆盖
  `icon-source.png`，或删掉它后重新运行 `创建快捷方式.bat`，
  脚本会自动改用 `New-WhaleIcon.ps1` 绘制

### 图标没生效？

Windows 的**图标缓存按「图标文件路径」做键**。如果只替换 `dsh-whale.ico` 的内容
而路径没变，资源管理器可能继续显示旧图标。

最省事的办法：**把新图标存成一个新的文件名**，再让快捷方式指向它。
另外，注销一次再登录（或重启）也一定能刷新。

> 早期版本里有个 `Fix-Desktop-Icon.bat` 专做这件事（删除 `iconcache_*.db`
> 并重启资源管理器）。它属于"系统级"操作、风险偏高，已从本仓库移除。
> 需要时手动执行即可：
>
> ```bat
> taskkill /f /im explorer.exe
> del /f /q "%LOCALAPPDATA%\Microsoft\Windows\Explorer\iconcache*"
> start explorer.exe
> ```

## 文件结构

```
.
├─ README.md
├─ LICENSE                原创代码：MIT（作者 subtob）
├─ NOTICE.md              AI 生成声明（DSH V4.1 FLASH）
├─ ICON-CREDITS.md        图标素材：CC BY-NC-SA 4.0（必读）
├─ .gitignore
└─ scripts/
   ├─ 创建快捷方式.bat        一键创建快捷方式 ← 先双击这个（文件名中文，内容纯 ASCII）
   ├─ Install-Shortcut.ps1   安装逻辑 + 写 Install-Log.txt
   ├─ Create-DSH-Shortcut.ps1 生成 .lnk（决定用哪个图标）
   ├─ launch.bat             启动器（主入口）
   ├─ Launch-DSH.ps1         启动逻辑：查 npx、探测端口、中文提示
   ├─ Launch-DSH-Hidden.vbs  静默桥：隐藏控制台窗口
   ├─ Convert-PngToIcon.ps1  PNG/JPG → 多尺寸 .ico（含去白边）
   ├─ New-WhaleIcon.ps1      代码绘制备用图标（GDI+）
   ├─ icon-source.png        当前图标原图（CC BY-NC-SA 4.0，可替换）
   ├─ dsh-whale.ico          生成的图标（CC BY-NC-SA 4.0）
   ├─ dsh-whale-drawn.ico    代码绘制的备用图标（MIT）
   └─ icon-preview.png       图标效果预览（CC BY-NC-SA 4.0）
```

## 改脚本前请看


1. **`.bat` / `.vbs` 的*内容*里不能有任何中文**（文件名可以）。
   中文 Windows 控制台代码页是 **936（GBK）**，而文件是 UTF-8 保存的。
   cmd.exe 按 GBK 去读 UTF-8 字节会把引号配对读坏，**整个批处理在第一行就中止**，
   表现是"双击了却什么都不发生、连报错都没有"。所以所有中文都在 `.ps1` 里。

2. **`.ps1` 必须存成 UTF-8 with BOM。**
   PowerShell 5.1 读无 BOM 的 UTF-8 文件会按 GBK 解码，中文字符串变乱码，
   **甚至直接语法错误、脚本完全无法运行**（本项目踩过：补 BOM 前
   `Install-Shortcut.ps1` 抛"字符串缺少终止符"）。

3. **图标缓存按路径做键。**
   换图标要换文件名，不能只换内容（见上文"图标没生效？"）。

4. **快捷方式里存的是绝对路径。**
   所以 `.lnk` 不纳入版本库，由安装脚本在本机生成。**移动目录后必须重装快捷方式。**

5. **不要用单一的 `Test-Path` 判断文件是否创建成功。**
   在沙箱、按需加载的虚拟磁盘、杀软实时扫描等环境下，文件刚写完的瞬间
   `Test-Path` 可能返回 false，于是**明明建成功却被报成失败**（实测踩到）。
   改为「重试 + 多重证据」：文件长度 > 0，且能用 Shell 打开并读到 TargetPath。

6. **不能把"已存在的快捷方式"当成可复用的模板。**
   一个 `.lnk` 可能指向**已被删除的目录**，此时它"文件存在"却完全无效：
   桌面图标变成**白色方块**，双击报**找不到文件**。判断可用性必须同时检查
   目标程序、参数里引用的脚本、以及图标文件是否都还在。

7. **先本地生成、再复制出去。**
   早期版本先写桌面，失败才退到本目录，而那个退路被状态变量挡住，
   于是桌面写不进去时本地也没生成，却照样打印"完成"。现在固定为
   "先在脚本目录生成权威 `.lnk`，再复制到桌面/开始菜单"。

## 图标授权

仓库内的鲸鱼娘图标**不是本项目原创，也不是 DeepSeek 官方素材**，
来自第三方仓库，协议为 **CC BY-NC-SA 4.0**：

- **BY** 署名：角色形象「溟月」— 上善无形；二创 — ZipZipPipe；修复 — QYQCAMIAO
- **NC** 非商用：本项目及其图标**不得用于商业目的**
- **SA** 相同方式共享：图标及其衍生文件（如生成的 `.ico`）须继续以 CC BY-NC-SA 4.0 分发

完整署名链条与合规说明见 **[ICON-CREDITS.md](ICON-CREDITS.md)**。

本仓库**不是纯 MIT**：本项目自己编写的**全部脚本代码**采用 **MIT**
（作者 subtob，见 [LICENSE](LICENSE)），代码绘制的图标 `dsh-whale-drawn.ico`
也属于 MIT 范围；但上面那份鲸鱼娘素材及其衍生的 `.ico` 属于
**CC BY-NC-SA 4.0，明确排除在 MIT 之外**。两套协议分别适用于各自部分，请勿混用。

## AI 生成声明

本项目在 AI 编程代理辅助下生成：**DeepSeek Harness（`dsh`）+ 模型 DSH V4.1 FLASH
（`deepseek-flash`）**，人类作者 **subtob**（https://github.com/subtob）负责提出需求、
审阅与测试。AI 辅助范围包括移植性/一致性检查与部分重写，项目基于作者原有的 Bash 脚本。

详见 **[NOTICE.md](NOTICE.md)**。请注意脚本会修改桌面/开始菜单快捷方式，
**运行前请先读脚本注释**。

## English

A tiny Windows helper that launches the DeepSeek Harness Web UI.

**Requirements** — Windows 10/11, Node.js with `npx` on `PATH`. No admin rights needed.

**Quick start** — double-click `scripts\创建快捷方式.bat` ("create shortcut").
The file name is Chinese but its content is pure ASCII. It creates a
"DSH 快速启动" shortcut on your Desktop and in the Start Menu; the window
closes by itself when it is done.

**Command line**

```bat
scripts\launch.bat --port 8080
```

**How it works** — opens a PowerShell window and runs
`npx @deepseek-ai/dsh web --port <PORT> --host 127.0.0.1`. If the port is already
listening, it just opens the browser instead of starting a second server.

**Notes for contributors**

- `.bat` / `.vbs` **content** must stay **pure ASCII** (file names may be Chinese).
  On a Chinese Windows console (code page 936/GBK), UTF-8 Chinese text inside a
  batch file corrupts quote pairing and aborts the script on line 1 with no
  error output.
- `.ps1` files must be saved as **UTF-8 with BOM**, or PowerShell 5.1 mis-decodes
  them and the script fails to parse at all.
- Windows' icon cache is keyed by the icon **path**, so changing an icon's contents
  in place often does not refresh it.
- Shortcuts store absolute paths, which is why no `.lnk` is committed.
- Never trust a bare `Test-Path` to decide whether a file was created; retry and
  require multiple pieces of evidence.
- A shortcut is only usable if its target, its argument script and its icon all
  still exist — otherwise the desktop shows a blank icon.

**License** — this repository is **not MIT-only**. Our scripts (MIT, author:
subtob) and the bundled whale-girl artwork (**CC BY-NC-SA 4.0**: attribution
required, non-commercial only, share-alike) are licensed separately. See
[LICENSE](LICENSE) and [ICON-CREDITS.md](ICON-CREDITS.md).

**AI generation notice** — built with the assistance of DeepSeek Harness (`dsh`)
running model **DSH V4.1 FLASH** (`deepseek-flash`), under the direction and
review of the human author subtob. See [NOTICE.md](NOTICE.md).

## 致谢

- 图标素材：[fornarwhal/deepseek-whale-girl-icon](https://github.com/fornarwhal/deepseek-whale-girl-icon)（CC BY-NC-SA 4.0）
- 角色形象：上善无形（OC「溟月」）· 二创：ZipZipPipe · 修复：QYQCAMIAO
- 生成工具：DeepSeek Harness（`dsh`）+ 模型 DSH V4.1 FLASH（`deepseek-flash`）
- DeepSeek Harness 由 DeepSeek 提供；本项目为第三方工具，与 DeepSeek 无隶属关系
