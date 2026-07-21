#!/bin/bash
# ============================================================
# 安格斯配置管理脚本
# 用法:
#   ./agnes-config.sh init          — 初始化配置（录入 API Key）
#   ./agnes-config.sh show          — 查看配置状态
#   ./agnes-config.sh check         — 验证 API Key 是否有效
#   ./agnes-config.sh path          — 输出图片目录路径
# ============================================================
set -e

CONFIG_DIR="${HOME}/.config/agnes-bridge"
CONFIG_FILE="${CONFIG_DIR}/config.json"
IMG_DIR="${HOME}/Desktop/DeepSeek"

ensure_img_dir() {
  mkdir -p "${IMG_DIR}"
}

cmd_init() {
  ensure_img_dir
  mkdir -p "${CONFIG_DIR}"
  if [ -f "${CONFIG_FILE}" ]; then
    echo "⚠️  配置文件已存在: ${CONFIG_FILE}"
    read -p "是否重新配置？(y/N): " answer
    if [ "${answer}" != "y" ] && [ "${answer}" != "Y" ]; then
      echo "已取消"
      exit 0
    fi
  fi
  read -sp "请输入安格斯（Agnes）API Key: " api_key
  echo ""
  if [ -z "${api_key}" ]; then
    echo "❌ API Key 不能为空"
    exit 1
  fi

  # 验证 API Key 是否有效
  echo "🔍 正在验证 API Key ..."
  TEST_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://apihub.agnes-ai.com/v1/chat/completions" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d '{"model":"agnes-2.0-flash","messages":[{"role":"user","content":"hi"}],"max_tokens":5}' \
    --connect-timeout 10 2>/dev/null)

  if [ "${TEST_RESULT}" = "200" ]; then
    echo "✅ API Key 验证通过！"
  else
    echo "⚠️  API Key 验证返回 HTTP ${TEST_RESULT}"
    echo "   网络可能不稳定，或 Key 无效。配置将继续但请注意检查。"
  fi

  cat > "${CONFIG_FILE}" << EOF
{
  "AGNES_API_KEY": "${api_key}",
  "IMG_DIR": "${IMG_DIR}",
  "initialized_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
  chmod 600 "${CONFIG_FILE}"
  echo ""
  echo "✅ 配置已保存到 ${CONFIG_FILE}"
  echo "✅ 图片目录: ${IMG_DIR}"
  echo ""
  echo "📌 使用说明："
  echo "   说"画一张..."→ 安格斯自动生图，存到桌面 DeepSeek 文件夹"
  echo "   说"看看这张图"→ 把图放桌面 DeepSeek 文件夹，我来分析"
}

cmd_show() {
  if [ ! -f "${CONFIG_FILE}" ]; then
    echo "❌ 未配置，请先运行: ./agnes-config.sh init"
    exit 1
  fi
  api_key=$(grep -o '"AGNES_API_KEY": *"[^"]*"' "${CONFIG_FILE}" | cut -d'"' -f4)
  masked="${api_key:0:4}****${api_key: -4}"
  echo "🔑 API Key: ${masked}"
  echo "📂 图片目录: ${IMG_DIR}"
  echo "📅 初始化时间: $(grep -o '"initialized_at": *"[^"]*"' "${CONFIG_FILE}" | cut -d'"' -f4)"
  if [ -d "${IMG_DIR}" ]; then
    count=$(ls -1 "${IMG_DIR}" 2>/dev/null | wc -l)
    echo "🖼️  图片数量: ${count}"
  fi
}

cmd_check() {
  if [ ! -f "${CONFIG_FILE}" ]; then
    echo "❌ 未配置 API Key"
    exit 1
  fi
  api_key=$(grep -o '"AGNES_API_KEY": *"[^"]*"' "${CONFIG_FILE}" | cut -d'"' -f4)
  masked="${api_key:0:4}****${api_key: -4}"

  echo "🔍 测试安格斯 API 连接 ..."
  echo "   Key: ${masked}"
  echo ""

  # 测试聊天 API
  echo "--- 测试 agnes-2.0-flash（读图模型）---"
  CHAT_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://apihub.agnes-ai.com/v1/chat/completions" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d '{"model":"agnes-2.0-flash","messages":[{"role":"user","content":"hi"}],"max_tokens":5}' \
    --connect-timeout 10 2>/dev/null)
  if [ "${CHAT_RESULT}" = "200" ]; then
    echo "   ✅ 连接成功 (HTTP 200)"
  else
    echo "   ❌ 连接失败 (HTTP ${CHAT_RESULT})"
  fi

  # 测试生图 API
  echo "--- 测试 agnes-image-2.0-flash（生图模型）---"
  IMAGE_RESULT=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "https://apihub.agnes-ai.com/v1/images/generations" \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    -d '{"model":"agnes-image-2.0-flash","prompt":"test","extra_body":{"response_format":"url"}}' \
    --connect-timeout 10 2>/dev/null)
  if [ "${IMAGE_RESULT}" = "200" ]; then
    echo "   ✅ 连接成功 (HTTP 200)"
  else
    echo "   ❌ 连接失败 (HTTP ${IMAGE_RESULT})"
  fi

  echo ""
  if [ "${CHAT_RESULT}" = "200" ] && [ "${IMAGE_RESULT}" = "200" ]; then
    echo "✅ 全部就绪，可以正常使用！"
  else
    echo "⚠️  部分服务不可用，请检查网络或 API Key"
  fi
}

cmd_path() {
  ensure_img_dir
  echo "${IMG_DIR}"
}

case "${1:-help}" in
  init) cmd_init ;;
  show) cmd_show ;;
  check) cmd_check ;;
  path) cmd_path ;;
  *)
    echo "用法: $0 {init|show|check|path}"
    echo ""
    echo "  init   — 初始化/重新配置安格斯 API Key"
    echo "  show   — 查看当前配置状态"
    echo "  check  — 验证 API Key 和网络连接"
    echo "  path   — 输出图片目录路径"
    exit 1
    ;;
esac
