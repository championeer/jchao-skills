#!/usr/bin/env python3
"""DashScope Fun-ASR — 批量转录课程录音，带重试和断点续传"""

import argparse, json, os, subprocess, sys, time
from pathlib import Path


def convert_wav(src: Path, dst: Path) -> None:
    """将任意WAV转换为16kHz 16-bit mono（ASR所需格式）"""
    subprocess.run(
        ['ffmpeg', '-i', str(src), '-ar', '16000', '-ac', '1',
         '-sample_fmt', 's16', '-y', str(dst)],
        capture_output=True, check=True
    )


def transcribe_segment(wav_path: str, max_retries: int = 3) -> dict:
    """转录单个WAV文件，带重试逻辑"""
    from dashscope.audio.asr import Recognition, RecognitionCallback, RecognitionResult

    class _Cb(RecognitionCallback):
        def on_event(self, result): pass
        def on_complete(self): pass
        def on_error(self, result):
            print(f"  [ASR ERROR] {result}", file=sys.stderr)

    for attempt in range(max_retries):
        try:
            if attempt > 0:
                wait = 10 * (attempt + 1)
                print(f"  等待{wait}秒后重试...")
                time.sleep(wait)
                print(f"  转录中... (重试{attempt})")
            else:
                print(f"  转录中...")

            start = time.time()
            recognition = Recognition(
                model='fun-asr-realtime',
                callback=_Cb(),
                format='wav',
                sample_rate=16000
            )
            result = recognition.call(file=wav_path)
            elapsed = time.time() - start

            if result.output is None:
                raise RuntimeError("output is None — WebSocket 连接可能断开")

            sentences = result.output.get('sentence', [])
            full_text = ''.join(s['text'] for s in sentences)
            print(f"  完成: {len(sentences)}句, {len(full_text)}字, {elapsed:.1f}秒")

            return {
                'sentences': len(sentences),
                'chars': len(full_text),
                'text': full_text,
                'sentence_details': sentences,
                'elapsed': round(elapsed, 1)
            }

        except Exception as e:
            print(f"  失败: {e}", file=sys.stderr)
            if attempt == max_retries - 1:
                return {
                    'sentences': 0, 'chars': 0,
                    'text': f'[转录失败: {e}]',
                    'sentence_details': [], 'elapsed': 0
                }


def write_transcript_md(results: list, output_path: Path, course_num: str) -> None:
    """将全部转录结果写入Markdown文件"""
    with open(output_path, 'w') as f:
        f.write(f"# 第{course_num}课 录音转录稿\n\n")
        f.write(f"> 转录引擎：DashScope Fun-ASR-realtime\n")
        f.write(f"> 转录日期：{time.strftime('%Y-%m-%d')}\n")
        f.write(f"> 原始录音：{len(results)} 段 WAV\n\n---\n\n")

        for r in results:
            f.write(f"## 第{r['segment']:02d}段 — {r['filename']}\n\n")
            f.write(f"> 字数: {r['chars']}\n\n")
            for s in r.get('sentence_details', []):
                f.write(s['text'])
            f.write("\n\n---\n\n")

        total = sum(r['chars'] for r in results)
        f.write(f"## 统计\n\n- 总字数: {total}\n- 总段数: {len(results)}\n")


def main():
    parser = argparse.ArgumentParser(description='批量转录课程录音')
    parser.add_argument('src_dir', help='包含WAV文件的目录')
    parser.add_argument('output_md', help='输出Markdown文件路径')
    parser.add_argument('--course', default='XX', help='课次编号（用于标题）')
    parser.add_argument('--cache-dir', default='/tmp/course-asr-cache',
                        help='JSON缓存目录')
    parser.add_argument('--skip', default='', help='跳过的段号，逗号分隔')
    args = parser.parse_args()

    if not os.environ.get('DASHSCOPE_API_KEY'):
        print("错误: 请设置 DASHSCOPE_API_KEY 环境变量", file=sys.stderr)
        sys.exit(1)

    src_dir = Path(args.src_dir)
    cache_dir = Path(args.cache_dir)
    cache_dir.mkdir(parents=True, exist_ok=True)
    convert_dir = cache_dir / 'converted'
    convert_dir.mkdir(exist_ok=True)

    skip_segs = set(int(x) for x in args.skip.split(',') if x.strip())

    # 扫描WAV文件
    wav_files = sorted(src_dir.glob("*.wav"))
    if not wav_files:
        wav_files = sorted(src_dir.glob("*.WAV"))
    if not wav_files:
        print(f"错误: {src_dir} 中没有找到WAV文件", file=sys.stderr)
        sys.exit(1)

    print(f"找到 {len(wav_files)} 个WAV文件")
    if skip_segs:
        print(f"跳过段号: {sorted(skip_segs)}")

    results = []

    for i, wav_path in enumerate(wav_files):
        seg_num = i + 1
        print(f"\n[{seg_num}/{len(wav_files)}] {wav_path.name}")

        if seg_num in skip_segs:
            print(f"  跳过（配置排除）")
            continue

        # 检查缓存
        cache_file = cache_dir / f"seg{seg_num:02d}.json"
        if cache_file.exists():
            with open(cache_file) as f:
                cached = json.load(f)
            print(f"  已有缓存: {cached['chars']}字，跳过")
            results.append(cached)
            continue

        # 格式转换
        converted = convert_dir / f"seg{seg_num:02d}.wav"
        if not converted.exists():
            print(f"  转换格式...")
            try:
                convert_wav(wav_path, converted)
            except subprocess.CalledProcessError as e:
                print(f"  ffmpeg转换失败: {e}", file=sys.stderr)
                continue

        # 转录
        asr_result = transcribe_segment(str(converted))

        record = {
            'segment': seg_num,
            'filename': wav_path.name,
            **asr_result
        }

        # 立即缓存
        with open(cache_file, 'w') as f:
            json.dump(record, f, ensure_ascii=False, indent=2)

        results.append(record)

    # 按段号排序后写入Markdown
    results.sort(key=lambda r: r['segment'])
    output_path = Path(args.output_md)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    write_transcript_md(results, output_path, args.course)

    total_chars = sum(r['chars'] for r in results)
    print(f"\n转录稿已保存: {output_path}")
    print(f"总字数: {total_chars}")
    for r in results:
        print(f"  第{r['segment']:02d}段: {r['chars']:>5}字  {r['filename']}")


if __name__ == '__main__':
    main()
