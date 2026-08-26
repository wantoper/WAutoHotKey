# WAutoHotKey

窗口跳转管理工具 — 基于 AutoHotkey v2，通过全局热键快速切换/最小化指定窗口，带配置管理 UI 和窗口探测器。

## 功能特性

- **热键切换窗口**：按一次激活，再按一次最小化（Toggle）
- **配置管理 UI**：图形界面增删改窗口规则，实时生效
- **窗口探测器**：枚举所有顶层窗口，一键复制匹配条件，方便配置新窗口
- **外部配置文件**：规则存在 `config.ini`，修改不需要重新编译
- **排除正则**：同进程多窗口时（如 PyCharm 主窗口 vs 终端、Chrome vs DevTools），用正则排除不需要的窗口
- **托盘菜单**：快速打开配置管理、窗口探测器、重新加载、退出

## 快速开始

### 方式一：直接运行（需安装 AutoHotkey v2）

1. 安装 [AutoHotkey v2](https://www.autohotkey.com/download/2.0/)
2. 双击 `WAutoHotKey.ahk` 运行
3. 托盘区出现 AHK 图标，右键可打开配置管理

### 方式二：运行编译好的 EXE（无需安装 AHK）

从 [Releases](https://github.com/wantoper/WAutoHotKey/releases) 下载 `WAutoHotKey.exe`，双击即可运行。

### 开机自启

按 `Win+R` 输入 `shell:startup`，把 `WAutoHotKey.ahk`（或 exe）的快捷方式放入打开的文件夹。

## 默认热键

| 热键 | 窗口 | 说明 |
|---|---|---|
| `Ctrl+Alt+`` ` | PyCharm 终端 | 匹配标题含"终端"的 jetbrains_client64 窗口 |
| `Ctrl+Alt+1` | PyCharm 主窗口 | 排除终端/提交/设置等工具窗 |
| `Ctrl+Alt+2` | Xshell | |
| `Ctrl+Alt+3` | Chrome | 排除 DevTools/开发者工具窗口 |

> 反引号键在热键中用 `vkC0` 表示。

## 配置说明

### 热键格式

| 符号 | 按键 |
|---|---|
| `#` | Win |
| `!` | Alt |
| `^` | Ctrl |
| `+` | Shift |
| `vkC0` | 反引号 ` |

示例：`^!1` = Ctrl+Alt+1，`#c` = Win+C

### 匹配条件

支持以下方式任意组合（空格分隔）：

- `ahk_exe 进程名` — 按进程匹配，如 `ahk_exe chrome.exe`
- `标题关键词` — 标题包含此文字，如 `终端`
- `ahk_class 类名` — 按窗口类名匹配

组合示例：`终端 ahk_exe jetbrains_client64.exe`（标题含"终端"且进程是 jetbrains_client64）

### 排除正则

可选。标题匹配此正则的窗口会被跳过，用于同进程多窗口时排除工具窗/对话框。

- PyCharm 主窗口排除：`i)^(终端|提交|设置|运行|调试|...)`
- Chrome 排除 DevTools：`i)DevTools|开发者工具`

## 窗口探测器

托盘菜单 → 窗口探测器，打开后：

- 列表显示所有顶层窗口的句柄、标题、类名、进程名
- 双击某行 → 复制 `ahk_exe 进程名` 到剪贴板
- "复制标题匹配"按钮 → 复制窗口标题到剪贴板
- 复制后在配置管理的"编辑规则"里直接粘贴匹配条件

## 配置文件格式

`config.ini` 与程序同目录，每条规则一个 section：

```ini
[Rule0]
hotkey=^!2
name=Xshell
match=ahk_exe Xshell.exe
exclude=
enabled=1
```

可以手动编辑，也可以通过配置管理 UI 编辑（推荐）。

## 编译为 EXE

### 本地编译

安装 AutoHotkey v2 后，运行安装目录下 `Compiler\Ahk2Exe.exe`：

```
Ahk2Exe.exe /in WAutoHotKey.ahk /out WAutoHotKey.exe
```

### GitHub Actions 自动编译

推送代码到 `main` 分支后，Actions 自动编译并上传 Artifact。打 tag（如 `v1.0.0`）后自动创建 Release 并附带 exe。

详见 `.github/workflows/build.yml`。

## 项目结构

```
WAutoHotKey/
├── WAutoHotKey.ahk       # 主程序
├── config.ini             # 配置文件（首次运行自动生成）
├── README.md
└── .github/
    └── workflows/
        └── build.yml      # GitHub Actions 自动编译
```

## 注意事项

- 编译后的 exe 可能被杀毒软件误报（AHK 脚本注入机制），个人使用加白名单即可
- 如果目标程序以管理员身份运行，AHK 也需要以管理员身份运行才能正常操作窗口
- 热键冲突时会弹出提示，修改为其他热键即可

## License

MIT
