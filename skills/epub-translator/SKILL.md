---
name: epub-translator
description: Translate EPUB ebooks to any target language while preserving original formatting, layout, images, CSS styles, and metadata. Use when Claude needs to (1) translate an EPUB file to another language, (2) convert ebook language, (3) create multilingual versions of EPUB books, or (4) localize ebook content. Supports all languages including Chinese, Japanese, Korean, Spanish, French, German, etc.
---

# EPUB Translator

Translate EPUB ebooks while preserving structure, formatting, images, and metadata. Claude performs translation directly - no external API needed.

## Workflow

### Step 1: Extract EPUB

```bash
python scripts/epub_utils.py extract input.epub ./work_dir
```

Output (JSON):
```json
{
  "extract_dir": "./work_dir",
  "opf_path": "OEBPS/content.opf",
  "opf_full_path": "./work_dir/OEBPS/content.opf"
}
```

### Step 2: Get Content Files

```bash
python scripts/epub_utils.py content-files ./work_dir OEBPS/content.opf
```

Outputs paths to all XHTML/HTML files that need translation.

### Step 3: Translate Each File

For each content file, read the XHTML, translate text content while preserving HTML structure, then write back.

**Translation rules:**
- Preserve all HTML tags exactly
- Translate only text between tags
- Keep CSS class names, IDs, attributes unchanged
- Maintain whitespace and line breaks structure
- Skip content in `<script>`, `<style>`, `<code>`, `<pre>` tags

**Example translation approach for a file:**

```python
# Read file
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Claude translates the text content (preserving HTML)
# translated_content = ... 

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(translated_content)
```

### Step 4: Update Metadata

```bash
python scripts/epub_utils.py update-meta ./work_dir OEBPS/content.opf \
    --lang zh-CN --title-suffix "(中文翻译)"
```

Language codes: `zh-CN` (Simplified Chinese), `zh-TW` (Traditional Chinese), `ja` (Japanese), `ko` (Korean), `es` (Spanish), `fr` (French), `de` (German), etc.

### Step 5: Repack EPUB

```bash
python scripts/epub_utils.py pack ./work_dir output.epub
```

## Script Commands

| Command | Description |
|---------|-------------|
| `extract <epub> <dir>` | Extract EPUB to directory |
| `content-files <dir> <opf>` | List content files to translate |
| `update-meta <dir> <opf> --lang <code>` | Update language metadata |
| `pack <dir> <output>` | Repack into EPUB |

## What Gets Preserved

- ✅ Images, fonts, media files
- ✅ CSS stylesheets
- ✅ Table of contents structure
- ✅ Chapter organization
- ✅ Internal links
- ✅ HTML formatting and attributes

## Translation Guidelines

When translating XHTML content:

1. **Identify translatable text** - Text nodes between HTML tags
2. **Preserve structure** - All `<tags>`, attributes, CSS classes stay identical
3. **Handle inline formatting** - `<em>`, `<strong>`, `<span>` wrap translated text
4. **Skip non-text** - `<script>`, `<style>`, `<svg>`, `<math>` content unchanged
5. **Maintain entities** - `&nbsp;`, `&mdash;` etc. as appropriate for target language

## Example: Complete Translation

```bash
# 1. Extract
python scripts/epub_utils.py extract book.epub ./work

# 2. Get files (Claude reads output, processes each file)
python scripts/epub_utils.py content-files ./work OEBPS/content.opf

# 3. Claude reads each file, translates, writes back
# (Claude performs this step directly)

# 4. Update metadata  
python scripts/epub_utils.py update-meta ./work OEBPS/content.opf --lang zh-CN

# 5. Pack
python scripts/epub_utils.py pack ./work book_chinese.epub
```

## Notes

- Large books: Process chapter by chapter to manage context
- Complex formatting: Review output for edge cases
- Images with text: Not translated (embedded in image files)
