# AI 生成声明 / AI Generation Notice

## 中文

本项目在 AI 编程代理辅助下生成：

| 项 | 内容 |
|---|---|
| 工具 | DeepSeek Harness（`dsh`） |
| 模型 | DSH V4.1 FLASH（`deepseek-flash`） |
| 人类作者 | **subtob**（https://github.com/subtob） |

AI 辅助的范围包括：对本项目的**移植性/一致性检查**与**部分重写**，
项目基于作者原有的 Bash 脚本。

作者（subtob）负责提出需求、审阅与测试，并对最终发布结果负责。

**给使用者的提示：**

- 在依赖本项目前请自行审阅代码，尤其是涉及**文件系统写入、注册表、
  提权（UAC）**的部分；
- AI 生成内容可能存在错误或遗漏，本项目按"原样"提供，不附带任何担保；
- 脚本会修改你**桌面/开始菜单的快捷方式**，并可能删除并重建 Windows
  图标缓存（`iconcache_*.db`）、重启资源管理器。这些行为都在脚本注释中写明，
  请先阅读再运行。

## English

This project was generated with the assistance of an AI coding agent:

| Item | Value |
|---|---|
| Tool | DeepSeek Harness (`dsh`) |
| Model | DSH V4.1 FLASH (`deepseek-flash`) |
| Human author | **subtob** (https://github.com/subtob) |

The AI assistance covered a portability/consistency review and a partial
rewrite of this project, which is based on an original Bash script by the
author. The author directed, reviewed and tested the result and takes
responsibility for what is published.

**For users:**

- Review the code before relying on it, especially anything that writes to the
  filesystem, the registry, or requests elevation (UAC).
- AI-generated content may contain errors or omissions. This project is
  provided "as is", without warranty of any kind.
- The scripts modify Desktop / Start Menu shortcuts and may delete and rebuild
  the Windows icon cache (`iconcache_*.db`) and restart Explorer. Each of these
  behaviours is documented in the script comments — please read before running.

## 相关文件 / Related

- 许可证与适用范围：[LICENSE](LICENSE)
- 图标素材来源与署名：[ICON-CREDITS.md](ICON-CREDITS.md)
- 使用说明：[README.md](README.md)
