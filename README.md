# 赵老师的DeepSeek多模态

让 DeepSeek 通过安格斯（Agnes）获得读图和生图能力。

## 简介

DeepSeek 是纯文本模型，本身不支持图片。本插件在后台调用安格斯（Agnes）完成所有图片工作：

- **读图** → 转成文字描述传给 DeepSeek
- **生图** → 直接保存到桌面文件夹
- **上下文管理** → 自动压缩，不爆对话

## 安装方法

### 方式一：通过 Codex 插件市场（推荐）

1. 打开 Codex → 插件市场 → 搜索 "赵老师的DeepSeek多模态"
2. 安装后按提示录入安格斯 API Key

### 方式二：手动安装

```bash
git clone https://github.com/zhao-yan/deepseek-multimodal.git ~/plugins/deepseek
```

然后在 Codex 中安装此插件。

### 方式三：使用 skill-installer

```bash
# 在 Codex 中直接说 "安装 deepseek-multimodal 插件"
```

## 首次使用

```bash
cd ~/plugins/deepseek
bash scripts/agnes-config.sh init
```

按提示输入安格斯 API Key 即可。

## 使用方法

| 你说 | 效果 |
|------|------|
| "画一张橘猫坐在沙发上" | 安格斯生图，保存到 ~/Desktop/DeepSeek/ |
| "看看这张图" | 请把图放 ~/Desktop/DeepSeek/，安格斯分析后文字描述 |
| "把上一张图改成水墨风格" | 读图 → 生新图，都在桌面上 |

## 网络要求

安格斯 API（apihub.agnes-ai.com）国内可直接访问，**不需要梯子**。

## 目录结构

```
deepseek-multimodal/
├── README.md
├── .codex-plugin/
│   └── plugin.json          — 插件清单
├── skills/
│   └── SKILL.md             — 规则 + 工作流
└── scripts/
    ├── agnes-config.sh      — 配置 API Key
    ├── agnes-vision.sh      — 读图
    └── agnes-image.sh       — 生图
```
