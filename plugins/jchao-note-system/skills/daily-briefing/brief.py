import os
import sys
import argparse
from datetime import datetime

def get_tasks(target_date, base_path):
    tasks_dir = os.path.join(base_path, "20-Structured/tasks")
    found_tasks = []
    
    # Search all markdown files in tasks_dir recursively
    for root, dirs, files in os.walk(tasks_dir):
        for file in files:
            if file.endswith(".md"):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        for line in f:
                            if f"due:{target_date}" in line:
                                found_tasks.append(line.strip())
                except Exception as e:
                    pass
    return found_tasks

def get_events(target_date, base_path):
    year, month, day = target_date.split("-")
    events_file = os.path.join(base_path, f"20-Structured/events/{year}/{year}-{month}.md")
    found_events = []
    
    if not os.path.exists(events_file):
        return found_events
    
    try:
        with open(events_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            
        in_section = False
        target_header = f"## {target_date}"
        
        for line in lines:
            if line.startswith("## "):
                if line.strip() == target_header:
                    in_section = True
                else:
                    in_section = False
            elif in_section and line.strip().startswith("- "):
                found_events.append(line.strip())
    except Exception as e:
        pass
        
    return found_events

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", help="Target date in YYYY-MM-DD format")
    parser.add_argument("--base", default="/Users/qianli/1-NOTES", help="Base path for notes")
    args = parser.parse_args()
    
    target_date = args.date or datetime.now().strftime("%Y-%m-%d")
    
    tasks = get_tasks(target_date, args.base)
    events = get_events(target_date, args.base)
    
    if not tasks and not events:
        print(f"### {target_date} 汇报\n\n今日暂无待办任务或预定事项。")
        return

    print(f"### {target_date} 汇报\n")
    
    if tasks:
        print("#### ✅ 今日任务 (Tasks)")
        for task in tasks:
            print(task)
        print()
        
    if events:
        print("#### 📅 今日事项 (Events)")
        for event in events:
            print(event)
        print()

if __name__ == "__main__":
    main()
