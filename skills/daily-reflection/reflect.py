import os
import argparse
from datetime import datetime

def get_daily_note(target_date, base_path):
    year = target_date.split("-")[0]
    note_path = os.path.join(base_path, f"10-DailyNotes/{year}/{target_date}.md")
    
    if not os.path.exists(note_path):
        return None
        
    try:
        with open(note_path, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception:
        return None

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", help="Target date YYYY-MM-DD")
    parser.add_argument("--base", default="/Users/qianli/1-NOTES", help="Base path for notes")
    args = parser.parse_args()
    
    target_date = args.date or datetime.now().strftime("%Y-%m-%d")
    content = get_daily_note(target_date, args.base)
    
    if not content:
        print(f"### {target_date} 晚间汇报\n\n今日未找到相关日志，卿是否忙碌得忘了动笔？")
        return

    print(f"### {target_date} 原始日志内容\n")
    print(content)

if __name__ == "__main__":
    main()
