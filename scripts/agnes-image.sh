#!/bin/bash
# ============================================================
# 安格斯生图脚本 — 直连安格斯 API，不依赖项目服务
#
# 用法:
#   ./agnes-image.sh <prompt> [图片尺寸]
#
# 流程:
#   1. 直调 Agnes agnes-image-2.0-flash (OpenAI 兼容格式)
#   2. 下载图片到 ~/Desktop/DeepSeek/
#   3. 输出文件路径
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
PROMPT="$1"
SIZE="${2:-1024x1024}"

if [ -z "${PROMPT}" ]; then
  echo "❌ 用法: $0 <文字描述> [图片尺寸]"
  echo "示例: $0 '一只橘猫坐在沙发上' 1024x1024"
  exit 1
fi

echo "🎨 正在生成图片..."
echo "📝 描述: ${PROMPT}"
echo "📐 尺寸: ${SIZE}"

mkdir -p "${IMG_DIR}"

# 直调 Agnes 生图 API
echo "📤 发送到安格斯 agnes-image-2.0-flash ..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "https://apihub.agnes-ai.com/v1/images/generations" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$(cat << EOF
{
  "model": "agnes-image-2.0-flash",
  "prompt": "${PROMPT}",
  "size": "${SIZE}",
  "extra_body": {
    "response_format": "url"
  }
}
EOF
)" 2>/dev/null)

HTTP_CODE=$(echo "${RESPONSE}" | tail -1)
BODY=$(echo "${RESPONSE}" | sed '$d')

# 解析返回的图片 URL
IMAGE_URL=$(echo "${BODY}" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    if 'error' in d:
        print('ERROR:' + d['error'].get('message', str(d['error'])))
    else:
        data = d.get('data', [{}])
        print(data[0].get('url', '') if data else '')
except Exception as e:
    print('ERROR:' + str(e))
" 2>/dev/null)

if echo "${IMAGE_URL}" | grep -q "^ERROR:"; then
  ERR_MSG=$(echo "${IMAGE_URL}" | sed 's/^ERROR://')
  echo "❌ 生图失败: ${ERR_MSG}"
  exit 1
fi

if [ -z "${IMAGE_URL}" ]; then
  echo "❌ 生图失败，API 返回空 (HTTP ${HTTP_CODE})"
  echo "返回: ${BODY}"
  exit 1
fi

echo "✅ 图片已生成: ${IMAGE_URL}"

# 下载图片到本地
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
FILENAME_PREFIX=$(echo "${PROMPT}" | tr -cd 'a-zA-Z0-9\u4e00-\u9fa5' | head -c 20)
if [ -z "${FILENAME_PREFIX}" ]; then
  FILENAME_PREFIX="image"
fi
LOCAL_FILE="${IMG_DIR}/${TIMESTAMP}-${FILENAME_PREFIX}.png"

echo "⬇️  下载到本地: ${LOCAL_FILE}"
curl -s -L "${IMAGE_URL}" -o "${LOCAL_FILE}" 2>/dev/null

if [ -f "${LOCAL_FILE}" ]; then
  FILE_SIZE=$(stat -f%z "${LOCAL_FILE}" 2>/dev/null || stat --format=%s "${LOCAL_FILE}" 2>/dev/null || echo "?")
  echo ""
  echo "✅ 图片已保存!"
  echo "📂 路径: ${LOCAL_FILE}"
  echo "📏 大小: ${FILE_SIZE} 字节"
else
  echo "⚠️  下载失败，请手动下载: ${IMAGE_URL}"
  echo "  保存到: ${LOCAL_FILE}"
fi

echo ""
echo "💡 提示: 在对话中告知用户图片位置即可，不要输出图片本身"
