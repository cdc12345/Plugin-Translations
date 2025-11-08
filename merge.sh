#!/bin/bash
set -euo pipefail

OUTPUT_DIR="lang"
ZIP_FILE="lang.zip"
PLUGIN_FILE="plugin.json"

# 清理旧结果
echo "🧹 清理旧的输出..."
rm -rf "$OUTPUT_DIR" "$ZIP_FILE"
mkdir -p "$OUTPUT_DIR"

echo "🔍 开始扫描并合并 *.properties 文件..."

# 查找所有 .properties 文件并合并
find . -type f -name "*.properties" | while read -r file; do
    filename=$(basename "$file")
    output_file="$OUTPUT_DIR/$filename"

    echo "# ===== 来自：$file =====" >> "$output_file"
    cat "$file" >> "$output_file"
    echo >> "$output_file"
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

echo "✅ 未发现重复键，开始打包..."

# 创建 zip 包
if [ -f "$PLUGIN_FILE" ]; then
    zip -r "$ZIP_FILE" "$OUTPUT_DIR" "$PLUGIN_FILE" > /dev/null
else
    zip -r "$ZIP_FILE" "$OUTPUT_DIR" > /dev/null
fi

echo "🎉 打包完成：$ZIP_FILE"
