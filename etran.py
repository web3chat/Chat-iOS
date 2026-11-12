import re
import time
import urllib.parse
import urllib.request

# ================= 配置 =================
INPUT_FILE = "Localizable_Draft.txt"
OUTPUT_FILE = "Localizable_EN.strings"
# ========================================

def google_translate(text, target_lang='en'):
    """使用内置库调用 Google 翻译接口 (免安装)"""
    try:
        url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=" + target_lang + "&dt=t&q=" + urllib.parse.quote(text)
        headers = {'User-Agent': 'Mozilla/5.0'}
        request = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(request) as response:
            result = response.read().decode('utf-8')
            # 提取 JSON 结果中的文本部分
            translated_text = re.search(r'\[\[\["([^"]+)"', result)
            if translated_text:
                return translated_text.group(1).replace('\\"', '"')
    except Exception as e:
        print(f"翻译出错: {text}, 错误: {e}")
    return text

def main():
    if not open(INPUT_FILE, 'r'): return
    
    print(f"开始读取 {INPUT_FILE} 并翻译成英文...")
    
    with open(INPUT_FILE, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    # 正则匹配 "Key" = "Value";
    pattern = re.compile(r'"([^"]+)"\s*=\s*"([^"]+)";')
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f_out:
        total = len(lines)
        for index, line in enumerate(lines):
            match = pattern.search(line)
            if match:
                key = match.group(1)
                value = match.group(2)
                
                # 翻译
                translated_value = google_translate(value)
                
                # 写入标准 iOS 格式
                f_out.write(f'"{key}" = "{translated_value}";\n')
                
                # 打印进度
                if index % 5 == 0:
                    print(f"进度: {index}/{total}...")
                
                # 稍微控制频率，防止被封 IP
                time.sleep(0.5)
            else:
                # 保持原样（注释或空行）
                f_out.write(line)

    print(f"\n✅ 翻译完成！生成文件: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
