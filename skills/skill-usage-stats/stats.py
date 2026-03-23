import os
import argparse
import re
from datetime import datetime
from collections import Counter

def analyze_logs(log_path):
    if not os.path.exists(log_path):
        return Counter()

    # 改进的正则匹配，更准确地提取技能目录名称
    # 匹配 skills/ 后面跟随的字母、数字、破折号及下划线，不包括扩展名或特殊字符
    skill_pattern = re.compile(r'skills/([a-zA-Z0-0\-_]+)')
    
    usage_stats = Counter()
    
    try:
        with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                # 只在包含技能相关操作的日志行中进行匹配
                if 'skills/' in line:
                    matches = skill_pattern.findall(line)
                    for skill_name in matches:
                        # 过滤常见的无关目录名
                        if skill_name in ['JChao_Skills', 'skills', 'daily-briefing', 'daily-reflection', 'skill-usage-stats']:
                            continue
                        usage_stats[skill_name] += 1
    except Exception as e:
        print(f"Error reading log: {e}")
        
    return usage_stats

def main():
    log_file = os.path.expanduser("~/.openclaw/logs/gateway.log")
    stats = analyze_logs(log_file)
    
    if not stats:
        print("未发现有效技能调用记录。")
        return

    print(f"### 技能调用统计 (基于日志分析)\n")
    print("| 技能名称 | 调用次数 |")
    print("| :--- | :--- |")
    
    # 按调用次数降序排列
    for skill, count in stats.most_common():
        print(f"| {skill} | {count} |")

if __name__ == "__main__":
    main()
