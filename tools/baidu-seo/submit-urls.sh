#!/bin/bash

# 定义输入文件和输出文件
INPUT_FILE="urls.txt"
OUTPUT_FILE="urls-push.txt"
NEXT_LINE_NO_FILE="next-line-no.txt"
BAIDU_API_TOKEN_FILE="baidu-api-token.txt"

# 从 next-line-no.txt 文件中读取起始行号
if [[ -f "$NEXT_LINE_NO_FILE" && -s "$NEXT_LINE_NO_FILE" ]]; then
    START_LINE=$(head -n 1 "$NEXT_LINE_NO_FILE")
else
    echo "Error: $NEXT_LINE_NO_FILE is missing or empty."
    exit 1
fi

# 从 baidu-api-token.txt 文件中读取 API Token
if [[ -f "$BAIDU_API_TOKEN_FILE" && -s "$BAIDU_API_TOKEN_FILE" ]]; then
    BAIDU_API_TOKEN=$(head -n 1 "$BAIDU_API_TOKEN_FILE")
else
    echo "Error: $BAIDU_API_TOKEN_FILE is missing or empty."
    exit 1
fi

# 读取的行数。api有每日推送额度限制
NUM_LINES=10

# 清空或创建输出文件
> "$OUTPUT_FILE"

# 使用 tail 和 head 提取指定范围的行
tail -n +$START_LINE "$INPUT_FILE" | head -n $NUM_LINES > "$OUTPUT_FILE"

# 输出完成信息
echo "Lines $START_LINE to $(($START_LINE + $NUM_LINES - 1)) have been extracted and saved to $OUTPUT_FILE"

# 推送百度api
curl -H 'Content-Type:text/plain' --data-binary @$OUTPUT_FILE "http://data.zz.baidu.com/urls?site=https://handsomestwei.top&token=$BAIDU_API_TOKEN"