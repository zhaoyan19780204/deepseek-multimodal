#!/bin/bash
# ============================================================
# 安格斯读图脚本 — 直连安格斯 API，不依赖项目服务
#
# 用法:
#   ./agnes-vision.sh <图片文件路径> [提示词]
#
# 流程:
#   1. 图片转 base64 data URI
#   2. 直调 Agnes agnes-2.0-flash (OpenAI 兼容格式)
#   3. 文字描述保存到 ~/Desktop/DeepSeek/
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${HOME}/.config/agnes-bridge/config.json"
IMG_DIR="${HOME}/Desktop/DeepSeek"

# 读取配置
if [ ! -f "${CONFIG_FILE}" ]; then
  echo "❌ 未配置，请先运行: ./agnes-config.sh init"
  exit 1
fi

API_KEY=$(grep -o '"AGNES_API_KEY": *"[^"]*"' "${CONFIG_FILE}" | cut -d'"' -f4)
IMAGE_FILE="$1"
PROMPT="${2:-请详细描述这张图片的内容，包括画面元素、颜色、构图、文字（如有）等。}"

if [ -z "${IMAGE_FILE}" ]; then
  echo "❌ 用法: $0 <图片文件路径> [提示词]"
  echo "示例: $0 ~/Desktop/DeepSeek/photo.jpg"
  exit 1
fi

if [ ! -f "${IMAGE_FILE}" ]; then
  echo "❌ 文件不存在: ${IMAGE_FILE}"
  exit 1
fi

echo "🔍 正在分析图片: ${IMAGE_FILE}"
echo "📝 提示词: ${PROMPT}"

mkdir -p "${IMG_DIR}"

# 图片 → base64 data URI
MIME_TYPE="image/jpeg"
EXT="${IMAGE_FILE##*.}"
case "${EXT,,}" in
  png)  MIME_TYPE="image/png" ;;
  jpg|jpeg) MIME_TYPE="image/jpeg" ;;
  webp) MIME_TYPE="image/webp" ;;
  gif)  MIME_TYPE="image/gif" ;;
  bmp)  MIME_TYPE="image/bmp" ;;
esac

BASE64_DATA=$(base64 -i "${IMAGE_FILE}" | tr -d '\n')
DATA_URI="data:${MIME_TYPE};base64,${BASE64_DATA}"

# 直调 Agnes API (OpenAI 兼容格式)
echo "📤 发送到安格斯 agnes-2.0-flash ..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://apihub.agnes-ai.com/v1/chat/completions" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(cat << EOF
{
  "model": "agnes-2.0-flash",
  "messages": [
    {
      "role": "user",
      "content": [
        {"type": "text", "text": "${PROMPT}"},
        {"type": "image_url", "image_url": {"url": "${DATA_URI}"}}
      ]
    }
  ],
  "temperature": 0.3,
  "max_tokens": 2000
}
EOF
)" 2>/dev/null)

HTTP_CODE=$(echo "${RESPONSE}" | tail -1)
BODY=$(echo "${RESPONSE}" | sed '$d')

# 解析响应
CONTENT=$(echo "${BODY}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if 'error' in d:
        print('ERROR:' + d['error'].get('message', str(d['error'])))
    else:
        print(d.get('choices', [{}])[0].get('message', {}).get('content', ''))
except Exception as e:
    print('ERROR:' + str(e))
" 2>/dev/null)

if echo "${CONTENT}" | grep -q "^ERROR:"; then
  ERR_MSG=$(echo "${CONTENT}" | sed 's/^ERROR://')
  echo "❌ 读图失败: ${ERR_MSG}"
  exit 1
fi

if [ -z "${CONTENT}" ]; then
  echo "❌ 读图失败，API 返回空 (HTTP ${HTTP_CODE})"
  echo "返回: ${BODY}"
  exit 1
fi

# 保存结果
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESULT_FILE="${IMG_DIR}/vision-结果-${TIMESTAMP}.txt"
echo "${CONTENT}" > "${RESULT_FILE}"

echo ""
echo "✅ 图片分析完成!"
echo "📄 结果已保存: ${RESULT_FILE}"
echo ""
echo "========== 图片描述 =========="
echo "${CONTENT}" | head -50
echo "================================"
echo ""
echo "💡 提示: 如需继续处理，可在对话中告知用户结果已保存在:"
echo "   ${RESULT_FILE}"
