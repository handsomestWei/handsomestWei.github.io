#!/bin/bash

# 定义输入文件和输出文件
SITEMAP_FILE="../../_site/sitemap.xml"
OUTPUT_FILE="urls.txt"

# 清空或创建输出文件
> "$OUTPUT_FILE"

# 提取 <loc> 标签中的内容并替换指定的前缀
grep -oP '(?<=<loc>)[^<]+' "$SITEMAP_FILE" | sed 's|https://handsomestwei.github.io/|https://handsomestwei.top/|' > "$OUTPUT_FILE"

# 输出完成信息
echo "URLs have been extracted and saved to $OUTPUT_FILE"