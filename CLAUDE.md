# CLAUDE.md

此文件为 Claude Code (claude.ai/code) 在此代码库中工作时提供指导。

## 交互规则（严格规定）

1. **语言要求**：请始终用**中文（简体）**进行回复。

2. **内部推理语言**：必须完全以**简体中文**来进行内部推理和思考过程，这是一项严格的规定。

3. **模型信息声明（必填）**：在每次聊天回复的开头，您必须明确说明以下信息：
   - 模型名称
   - 模型大小
   - 模型类型
   - 修订版本（更新日期）
   > 此规定仅适用于聊天回复，不适用于内联编辑操作。

4. **自动提交和推送（强制要求）**：
   - **每次修改文件后，必须立即执行 `/zcf:git-commit` 创建提交**
   - **提交后必须立即执行 `git push` 推送到远程仓库**
   - **无需等待用户明确指示，这是强制性的自动化行为**
   - **每次使用 Write、Edit、NotebookEdit 等工具修改文件后，都要执行此流程**

   **执行流程**：
   ```
   文件修改 → /zcf:git-commit → git push
   ```

   **例外情况**：
   - 计划模式（Plan Mode）下的规划阶段
   - 纯只读操作（Read、Grep、Glob 等）
   - 用户明确指示不要提交的情况
   
---

## 架构概述

此代码库具有双重用途：

1. **forztf-marketplace** - 托管插件的 Claude Code 插件市场
2. **ralph-wiggum-windows** - 为 Windows 实现 Ralph Wiggum 技术的实际插件

市场模式允许在单个仓库中托管多个插件。插件在 `.claude-plugin/marketplace.json` 中列出，`source` 路径指向它们的位置（可以是同一仓库插件的 `./`，或指向子目录的相对/绝对路径）。

### Ralph Wiggum 技术

此插件实现持续的自引用 AI 循环：

1. 用户使用任务提示启动循环
2. Claude 处理任务，修改文件
3. 当 Claude 退出时，**停止钩子**通过 `hooks/hooks.json` 拦截
4. 停止钩子（`stop-hook.ps1`）检查 `.claude/ralph-loop.local.md` 获取循环状态
5. 如果循环处于活动状态，相同的提示会被反馈并增加迭代计数器
6. 循环持续直到达到最大迭代次数或检测到完成承诺

**关键文件**：`.claude/ralph-loop.local.md` 包含用于状态的 YAML 前置元数据：
```yaml
---
active: true
iteration: 1
max_iterations: 0
completion_promise: "null"
started_at: "2024-01-07T12:00:00Z"
---
<原始提示内容>
```

## 开发命令

### 验证
```powershell
# 验证插件结构（调试关键）
claude plugin validate .claude/plugins/ralph-wiggum-windows

# 查看运行时的循环状态
Get-Content .claude/ralph-loop.local.md -Head 10

# 查看调试日志
Get-Content .claude/ralph-debug.log
```

### 测试命令
```bash
# 测试基本帮助
/ralph-wiggum-windows:help

# 测试短循环
/ralph-wiggum-windows:ralph-loop "测试任务" --max-iterations 2

# 取消活动循环
/ralph-wiggum-windows:cancel-ralph
```

### 安装测试
```powershell
# 测试安装程序（从仓库根目录）
powershell -ExecutionPolicy Bypass -File .\install.ps1

# 使用保留源标志测试
powershell -ExecutionPolicy Bypass -File .\install.ps1 -KeepSource
```

## 文件结构和约定

### 双语支持

所有内容都有英文和中文（`.zh`）版本：
- 命令：`ralph-loop.md` + `ralph-loop.zh.md`
- 钩子：`stop-hook.ps1` + `stop-hook.zh.ps1`
- 脚本：`setup-ralph-loop.ps1` + `setup-ralph-loop.zh.ps1`
- 文档：`README.md` + `README.zh.md`

### 插件元数据

**`.claude-plugin/plugin.json`** - 插件清单
- `repository` 必须是**字符串 URL**，不能是对象（常见错误）
- `version` 遵循语义化版本
- `keywords` 帮助可发现性

**`.claude-plugin/marketplace.json`** - 市场注册表
- `name` = 市场标识符
- `owner.name` = GitHub 用户名/组织
- `plugins[].source` = 插件路径（同仓库为 `./`）

### 命令前置元数据

命令是 `commands/` 目录中的 markdown 文件，带有 YAML 前置元数据：

```yaml
---
description: "在当前会话中启动 Ralph Wiggum 循环"
argument-hint: "PROMPT [--max-iterations N] [--completion-promise TEXT]"
allowed-tools: ["Bash(powershell.exe ...)"]
hide-from-slash-command-tool: "true"
---
```

命令调用格式：`/{插件名}:{命令名}` 或 `/{插件名}:{命令名}.zh`

### 钩子注册

`hooks/hooks.json` 定义生命周期钩子：

```json
{
  "description": "Ralph Wiggum Windows 插件停止钩子...",
  "hooks": {
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "powershell -NoProfile ... \"${CLAUDE_PLUGIN_ROOT}/hooks/stop-hook.ps1\""
      }]
    }]
  }
}
```

**关键环境变量**：`${CLAUDE_PLUGIN_ROOT}` 指向插件安装目录。

### 目录用途

- `commands/` - 斜杠命令定义（.md 文件）
- `hooks/` - 生命周期事件的 PowerShell 脚本
- `scripts/` - 辅助/设置脚本
- `docs/` - 技术文档（索引、序列图、深入分析）
- `.claude/` - **仅运行时状态**（gitignored，包含 ralph-loop.local.md、ralph-debug.log）

## PowerShell 优先设计

所有脚本使用 PowerShell（而非 bash）：
- JSON 解析：使用 `ConvertFrom-Json` 而非 `jq`
- 错误处理：`$ErrorActionPreference = "Stop"` 配合 try/catch
- 国际化的 UTF-8 编码：`[Console]::OutputEncoding = [System.Text.Encoding]::UTF8`
- 全面的 Windows 路径处理

## 完成承诺

循环终止使用输出中的 `<promise>` 标签：

```
<promise>任务完成</promise>
```

停止钩子使用正则表达式扫描转录稿中的这些标签。Claude 应仅在真正完成时输出 - 假阳性会破坏循环保证。

## 常见模式

### Git 仓库结构
```
forztf-marketplace/
├── .claude/              # 运行时状态（gitignored）
├── .claude-plugin/       # 插件元数据（已提交）
├── commands/             # 命令定义（已提交）
├── hooks/                # 钩子脚本（已提交）
├── scripts/              # 辅助脚本（已提交）
├── docs/                 # 文档（已提交）
└── install.ps1           # 安装程序（已提交）
```

### 调试日志格式
`.claude/ralph-debug.log` 包含带时间戳的条目：
- 钩子触发事件
- 状态文件解析结果
- 迭代决策
- 错误条件

### 插件验证清单
调试"找不到插件"时：
1. 检查 `plugin.json` 的 `repository` 是字符串 URL
2. 验证命令具有有效的 YAML 前置元数据
3. 确保钩子脚本可执行
4. 运行 `claude plugin validate <路径>`
5. 更改后重启 Claude Code
