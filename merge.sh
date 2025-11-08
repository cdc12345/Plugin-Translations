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
        # 提取 key（去掉注释行和空行），按 = 分割前半段为 key
        dup_keys=$(grep -v '^\s*#' "$f" | grep -v '^\s*$' | cut -d'=' -f1 | sed 's/[[:space:]]*$//' | sort | uniq -d)
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

# 如果存在 plugin.json，创建一个临时副本，替换占位符，保留原文件不变
TEMP_DIR=""
if [ -f "$PLUGIN_FILE" ]; then
    echo "🛠️ 准备替换 ${PLUGIN_FILE} 的 {supportedversion}（不修改原文件）..."
    TEMP_DIR=$(mktemp -d)
    temp_plugin_path="$TEMP_DIR/plugin.json"
    # 用 sed 替换占位符写入临时文件
    sed "s/{supportedversion}/${VERSION}/g" "$PLUGIN_FILE" > "$temp_plugin_path"
    echo "✅ 临时 plugin.json 已生成：$temp_plugin_path"
else
    echo "⚠️ 未找到 $PLUGIN_FILE，打包时将不包含 plugin.json。"
fi

echo "✅ 未发现重复键，开始打包..."

# 首先把 lang/ 打包，然后把临时 plugin.json（若存在）单独添加进 zip 的根目录（不带路径）
# 这样可以保证 lang/ 保持目录结构，且压缩包根目录包含 plugin.json（内容为替换后的副本）
zip -r "$ZIP_FILE" "$OUTPUT_DIR" > /dev/null

if [ -n "$TEMP_DIR" ] && [ -f "$TEMP_DIR/plugin.json" ]; then
    # 使用 -j 将临时文件作为根目录下的 plugin.json 添加到 zip 中
    zip -j "$ZIP_FILE" "$TEMP_DIR/plugin.json" > /dev/null
    echo "✅ 已将替换后的 plugin.json 添加到 $ZIP_FILE 根目录。"
fi

# 清理临时目录（如果有）
if [ -n "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
fi

echo "🎉 打包完成：$ZIP_FILE"
