import os
import re

# ================= 配置区 =================
# 1. 将此处改为你的项目真实根路径
project_path = "." 
# 2. 扫描的文件后缀
extensions = ('.m', '.h', '.swift', '.mm')
# ==========================================

# 匹配 Objective-C 的 @"内容" 或 Swift 的 "内容"
# 内部必须包含中文字符 (Unicode 范围: \u4e00-\u9fa5)
pattern = re.compile(r'@?"([^"]*[\u4e00-\u9fa5]+[^"]*)"')

found_dict = {}

print(f"开始扫描路径: {os.path.abspath(project_path)}")

for root, dirs, files in os.walk(project_path):
    for file in files:
        if file.endswith(extensions):
            file_path = os.path.join(root, file)
            try:
                # 使用 utf-8-sig 兼容带 BOM 的文件，errors='ignore' 防止因为非法字符报错
                with open(file_path, 'r', encoding='utf-8-sig', errors='ignore') as f:
                    content = f.read()
                    matches = pattern.findall(content)
                    for match in matches:
                        # 以中文内容作为 Key，去重
                        found_dict[match] = True
            except Exception as e:
                print(f"读取文件失败: {file_path}, 错误: {e}")

# 输出结果
output_file = 'Localizable_Draft.txt'
with open(output_file, 'w', encoding='utf-8') as f:
    f.write("// --- 自动提取的中文字符串 ---\n\n")
    for s in sorted(found_dict.keys()):
        # 生成标准 strings 格式: "原文" = "原文";
        line = f'"{s}" = "{s}";\n'
        f.write(line)

print(f"\n✅ 提取完成！")
print(f"共找到 {len(found_dict)} 条唯一中文词条。")
print(f"请查看当前目录下的文件: {output_file}")
