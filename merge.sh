#!/bin/bash
set -euo pipefail

OUTPUT_DIR="lang"
PLUGIN_FILE="plugin.json"

# 读取版本号
if [ ! -f ".version" ]; then
    echo "❌ 未找到 .version 文件！请在项目根目录创建一个包含版本号的 .version 文件。"
    exit 1
fi

VERSION=$(tr -d ' \n\r' < .version)
ZIP_FILE="TranslationPatch${VERSION}.zip"

echo "📦 检测到版本号：$VERSION"
echo "🧹 清理旧的输出..."
rm -rf "$OUTPUT_DIR" "$ZIP_FILE"
mkdir -p "$OUTPUT_DIR"

echo "🔍 开始扫描并合并 *.properties 文件..."

# 查找所有 .properties 文件并合并
find . -type f -name "*.properties" | while read -r file; do
    filename=$(basename "$file")
    output_file="$OUTPUT_DIR/$filename"

    {
        echo ""
        echo "    # ===== 来自：$file ====="
        cat "$file"
        echo ""
    } >> "$output_file"
done

echo "✅ 合并完成，开始检测重复键..."

# 检查重复键
has_error=false
for f in "$OUTPUT_DIR"/*.properties; do
    if [ -f "$f" ]; then
        # 提取 key（去掉注释行和空行）
        dup_keys=$(grep -v '^\s*#' "$f" | grep -v '^\s*$' | cut -d'=' -f1 | sort | uniq -d)
        if [ -n "$dup_keys" ]; then
            echo "❌ 错误：文件 $f 中存在重复的键："
            echo "$dup_keys" | sed 's/^/   - /'
            has_error=true
        fi
    fi
done

if [ "$has_error" = true ]; then
    echo "🚨 检测到重复键，已中止打包。请修复冲突后重试。"
    exit 1
fi

# 替换 plugin.json 中的 {supportedversion}
if [ -f "$PLUGIN_FILE" ]; then
    echo "🛠️ 正在替换 $PLUGIN_FILE 中的 {supportedversion}..."
    # 用临时文件防止直接修改出错
    sed "s/{supportedversion}/${VERSION}/g" "$PLUGIN_FILE" > "${PLUGIN_FILE}.tmp"
    mv "${PLUGIN_FILE}.tmp" "$PLUGIN_FILE"
    echo "✅ 已替换 plugin.json 中的 supportedversion。"
else
    echo "⚠️ 未找到 $PLUGIN_FILE，跳过版本替换。"
fi

echo "✅ 未发现重复键，开始打包..."

# 创建 zip 包
if [ -f "$PLUGIN_FILE" ]; then
    zip -r "$ZIP_FILE" "$OUTPUT_DIR" "$PLUGIN_FILE" > /dev/null
else
    zip -r "$ZIP_FILE" "$OUTPUT_DIR" > /dev/null
fi

echo "🎉 打包完成：$ZIP_FILE"
