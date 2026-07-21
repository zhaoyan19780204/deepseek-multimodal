---
name: 赵老师的DeepSeek多模态
description: 让 DeepSeek 通过安格斯（Agnes）获得读图和生图能力。安装时需录入安格斯 API Key。读图/生图结果放到 ~/Desktop/DeepSeek/，不污染对话上下文。当用户说"画图""生图""看看这张图""看图""生成图片""分析图片""描述图片""DeepSeek看图""帮我画"等时使用。
---

# 赵老师的DeepSeek多模态

本 Skill 为 DeepSeek（纯文本模型）提供「读图」和「生图」能力，通过安格斯（Agnes）模型透明完成。**所有图片处理过程不在对话中显示，上下文由本 Skill 管理，不会爆掉。**

---

## ⚠️ 硬性规则（违反 = 任务失败）

### 1. LLM 调用规则
- **所有 LLM 调用必须通过项目 API（localhost:4310）**，绝对不要在代码里拼 JSON 直接调 LLM
- 不要到处找脚本、不要调 OpenAI SDK、不要自己写 fetch 请求
- **每次调 LLM 只传当前任务相关的消息，最多 20 条**
- 不要累积对话历史，每完成一个阶段就清空上下文

### 2. 图片处理规则
- **DeepSeek 不支持图片输入**，不要传图片给 DeepSeek
- 安格斯（agnes-2.0-flash）负责读图，安格斯（agnes-image-2.0-flash）负责生图
- **不要直接把图片 base64 塞进 LLM 的 messages**
- 先看图片，把内容转成文字描述，再传给 LLM
- 图片分析结果存到文件，后续 LLM 调用只引用文件路径

### 3. 模型兼容性
- DeepSeek 系列模型 → 纯文本（不支持图片输入）
- 安格斯 agnes-2.0-flash → 支持读图（OpenAI 兼容格式）
- 安格斯 agnes-image-2.0-flash → 支持生图
- 纯文本任务走 DeepSeek，图片任务走安格斯

### 4. 文件操作规则
- 所有生成的图片先下载到本地 `~/Desktop/DeepSeek/` 目录
- 不使用临时 URL

---

## 技能目录

```
赵老师的DeepSeek多模态/
├── SKILL.md
└── scripts/
    ├── agnes-config.sh      — 配置 API Key / 验证连接
    ├── agnes-vision.sh      — 读图（返回文字描述）
    └── agnes-image.sh       — 生图（保存到桌面）
```

---

## 初始化流程（首次使用本 Skill 时执行）

### 步骤 1：录入安格斯 API Key

```bash
bash scripts/agnes-config.sh init
```

### 步骤 2：验证连接

```bash
bash scripts/agnes-config.sh check
```

### 步骤 3：告知用户

```text
✅ 赵老师的DeepSeek多模态 已就绪！
📂 图片目录: ~/Desktop/DeepSeek/
💡 你可以说"画一张..."或"看看这张图"来使用多模态能力。
```

---

## 生图流程（用户说"画图""生成图片""帮我画"等时触发）

### Step 1 — 确认需求

确认用户想要的画面内容、风格、尺寸（默认 1024×1024）。

### Step 2 — 调用安格斯生图（用户看不到）

```bash
bash scripts/agnes-image.sh "用户描述的画面内容，详细的英文prompt" "1024x1024"
```

脚本自动：
- 直调 `https://apihub.agnes-ai.com/v1/images/generations`
- 使用模型 `agnes-image-2.0-flash`
- 下载图片到 `~/Desktop/DeepSeek/`
- 输出文件路径

### Step 3 — 告知用户

```text
✅ 图片已生成！
📂 文件: ~/Desktop/DeepSeek/20260720_143020-橘猫坐在沙发上.png
💡 去桌面 DeepSeek 文件夹查看吧！
```

**关键原则：不在对话中输出图片、不传图片给 DeepSeek、只告知路径和文件名。**

---

## 读图流程（用户说"看看这张图""分析图片""描述图片"等时触发）

### Step 1 — 提示用户放图

```text
📂 请把需要分析的图片放到桌面 DeepSeek 文件夹：
   ~/Desktop/DeepSeek/
   
放好后告诉我文件名，我来分析。
```

### Step 2 — 用户放好图后，调用安格斯读图（用户看不到）

```bash
bash scripts/agnes-vision.sh "~/Desktop/DeepSeek/图片文件名.png" "请详细描述这张图片的内容"
```

脚本自动：
- 直调 `https://apihub.agnes-ai.com/v1/chat/completions`
- 使用模型 `agnes-2.0-flash`（支持图片输入）
- 图片转 base64 data URI 发送
- 把分析结果保存到 `~/Desktop/DeepSeek/vision-结果-{时间戳}.txt`

### Step 3 — 从结果文件中读取文字描述，用文字告诉用户

```bash
cat ~/Desktop/DeepSeek/vision-结果-{时间戳}.txt
```

然后把分析结果以**纯文字形式**告诉用户。

### Step 4 — 后续处理

- 如果用户看完图要求继续生图 → 执行生图流程
- 新生成的图片也放 `~/Desktop/DeepSeek/`
- 只告知路径，不给图片

---

## 上下文压缩规则（防超标）

DeepSeek 是纯文本模型，上下文一旦超限整个对话就废了。**本 Skill 强制实施以下压缩策略：**

### 自动压缩时机

- **每完成一个子任务后**（如一次生图或读图完成后）
- **每 3-5 轮工具调用后**
- **检测到工具调用超过 15 轮时**（不等子任务完成）
- 用户说 `继续` 或 `/next` 时

### 压缩方式

将当前进度写入 `~/.context-summary.md`：

```markdown
## 当前进度
<已完成的工作摘要>

## 关键状态
<关键变量、文件路径、配置状态>

## 下一步
<待完成的事项>
```

然后对用户说：

```text
📐 上下文压缩完成，继续下一步。
```

### 恢复方式

启动新阶段或用户说"继续"时，先读 `.context-summary.md` 恢复状态，不依赖对话历史。

---

## API 端点速查

| 端点 | 用途 | 模型 |
|------|------|------|
| `https://apihub.agnes-ai.com/v1/chat/completions` | 读图理解 | agnes-2.0-flash |
| `https://apihub.agnes-ai.com/v1/images/generations` | 生图 | agnes-image-2.0-flash |

---

## 网络要求

安格斯 API 部署在 Cloudflare 上：
- `apihub.agnes-ai.com` → 104.18.18.62 / 104.18.19.62
- 国内可直接访问，**不需要梯子**
- 首次使用请运行 `bash scripts/agnes-config.sh check` 验证连接

---

## 注意事项

1. **DeepSeek 做所有文字工作**：分析、写作、规划、对话
2. **安格斯只处理图片**：安格斯不在对话中"说话"，只安静地读图或生图
3. **图片不出现在对话中**：所有图片只看路径，不传 base64，不展示
4. **首次使用先配置**：`bash scripts/agnes-config.sh init`
5. **本 Skill 不传超过 20 条消息给 LLM**：每完成一阶段就压缩
6. **图片结果存文件**：后续调用只引用文件路径

---

## 违禁操作清单

以下操作禁止执行，违反导致对话失败：

- ❌ 把图片 base64 传给 DeepSeek
- ❌ 直接拼 JSON 调 LLM（必须走 localhost:4310）
- ❌ 在对话中展示图片
- ❌ 累计超过 20 条消息不压缩
- ❌ 找脚本/调 SDK 代替项目 API
