#!/usr/bin/env python3
"""
EPUB Utilities - Extract, modify, and repack EPUB files.

This script handles EPUB structure operations. Translation is performed
by Claude directly in the agent environment.

Usage:
    python epub_utils.py extract input.epub ./work_dir
    python epub_utils.py list-content input.epub
    python epub_utils.py pack ./work_dir output.epub
    python epub_utils.py update-lang ./work_dir zh-CN
"""

import argparse
import json
import os
import sys
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET


# EPUB namespace definitions
NAMESPACES = {
    'opf': 'http://www.idpf.org/2007/opf',
    'dc': 'http://purl.org/dc/elements/1.1/',
    'container': 'urn:oasis:names:tc:opendocument:xmlns:container',
}

for prefix, uri in NAMESPACES.items():
    ET.register_namespace(prefix, uri)


def extract_epub(epub_path: str, output_dir: str) -> dict:
    """
    Extract EPUB contents to directory.
    
    Returns metadata about the extracted EPUB.
    """
    output_path = Path(output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    with zipfile.ZipFile(epub_path, 'r') as zf:
        zf.extractall(output_dir)
    
    # Find and parse OPF
    container_path = output_path / "META-INF" / "container.xml"
    if not container_path.exists():
        raise FileNotFoundError("Invalid EPUB: container.xml not found")
    
    tree = ET.parse(container_path)
    root = tree.getroot()
    rootfile = root.find(".//{urn:oasis:names:tc:opendocument:xmlns:container}rootfile")
    
    if rootfile is None:
        raise ValueError("No rootfile in container.xml")
    
    opf_path = rootfile.get("full-path")
    
    return {
        "extract_dir": str(output_path),
        "opf_path": opf_path,
        "opf_full_path": str(output_path / opf_path),
    }


def list_content_files(epub_path: str) -> list[dict]:
    """
    List all translatable content files in EPUB.
    
    Returns list of content file info.
    """
    import tempfile
    
    with tempfile.TemporaryDirectory() as temp_dir:
        info = extract_epub(epub_path, temp_dir)
        opf_full_path = Path(info["opf_full_path"])
        opf_dir = opf_full_path.parent
        
        tree = ET.parse(opf_full_path)
        root = tree.getroot()
        
        content_files = []
        manifest = root.find(".//{http://www.idpf.org/2007/opf}manifest")
        
        if manifest is not None:
            for item in manifest.findall("{http://www.idpf.org/2007/opf}item"):
                media_type = item.get("media-type", "")
                href = item.get("href", "")
                item_id = item.get("id", "")
                
                if media_type in ["application/xhtml+xml", "text/html"]:
                    full_path = opf_dir / href
                    if full_path.exists():
                        content_files.append({
                            "id": item_id,
                            "href": href,
                            "path": str(full_path),
                            "media_type": media_type,
                        })
        
        return content_files


def get_content_files(extract_dir: str, opf_path: str) -> list[str]:
    """Get list of content file paths from extracted EPUB."""
    opf_full_path = Path(extract_dir) / opf_path
    opf_dir = opf_full_path.parent
    
    tree = ET.parse(opf_full_path)
    root = tree.getroot()
    
    content_files = []
    manifest = root.find(".//{http://www.idpf.org/2007/opf}manifest")
    
    if manifest is not None:
        for item in manifest.findall("{http://www.idpf.org/2007/opf}item"):
            media_type = item.get("media-type", "")
            href = item.get("href", "")
            
            if media_type in ["application/xhtml+xml", "text/html"]:
                full_path = opf_dir / href
                if full_path.exists():
                    content_files.append(str(full_path))
    
    return content_files


def update_metadata(extract_dir: str, opf_path: str, lang_code: str, title_suffix: str = ""):
    """Update EPUB metadata with new language and optional title suffix."""
    opf_full_path = Path(extract_dir) / opf_path
    
    tree = ET.parse(opf_full_path)
    root = tree.getroot()
    
    metadata = root.find(".//{http://www.idpf.org/2007/opf}metadata")
    if metadata is not None:
        # Update language
        lang = metadata.find(".//{http://purl.org/dc/elements/1.1/}language")
        if lang is not None:
            lang.text = lang_code
        
        # Update title if suffix provided
        if title_suffix:
            title = metadata.find(".//{http://purl.org/dc/elements/1.1/}title")
            if title is not None and title.text:
                if title_suffix not in title.text:
                    title.text = f"{title.text} {title_suffix}"
    
    tree.write(opf_full_path, encoding='utf-8', xml_declaration=True)
    print(f"Updated metadata: lang={lang_code}")


def pack_epub(source_dir: str, output_path: str):
    """Pack directory contents into EPUB file."""
    source_path = Path(source_dir)
    
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as zf:
        # mimetype must be first and uncompressed
        mimetype_path = source_path / "mimetype"
        if mimetype_path.exists():
            zf.write(mimetype_path, "mimetype", zipfile.ZIP_STORED)
        
        # Add all other files
        for root, dirs, files in os.walk(source_dir):
            for file in files:
                if file == "mimetype":
                    continue
                
                file_path = Path(root) / file
                arcname = file_path.relative_to(source_path)
                zf.write(file_path, arcname)
    
    print(f"Created EPUB: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="EPUB utility operations")
    subparsers = parser.add_subparsers(dest="command", required=True)
    
    # Extract command
    extract_parser = subparsers.add_parser("extract", help="Extract EPUB to directory")
    extract_parser.add_argument("epub", help="Input EPUB file")
    extract_parser.add_argument("output_dir", help="Output directory")
    
    # List content command
    list_parser = subparsers.add_parser("list-content", help="List content files")
    list_parser.add_argument("epub", help="Input EPUB file")
    list_parser.add_argument("--json", action="store_true", help="Output as JSON")
    
    # Get content files command
    content_parser = subparsers.add_parser("content-files", help="Get content file paths")
    content_parser.add_argument("extract_dir", help="Extracted EPUB directory")
    content_parser.add_argument("opf_path", help="OPF file path relative to extract_dir")
    
    # Update metadata command
    meta_parser = subparsers.add_parser("update-meta", help="Update EPUB metadata")
    meta_parser.add_argument("extract_dir", help="Extracted EPUB directory")
    meta_parser.add_argument("opf_path", help="OPF path")
    meta_parser.add_argument("--lang", help="Language code (e.g., zh-CN, ja, es)")
    meta_parser.add_argument("--title-suffix", help="Suffix to add to title")
    
    # Pack command
    pack_parser = subparsers.add_parser("pack", help="Pack directory into EPUB")
    pack_parser.add_argument("source_dir", help="Source directory")
    pack_parser.add_argument("output", help="Output EPUB file")
    
    args = parser.parse_args()
    
    if args.command == "extract":
        info = extract_epub(args.epub, args.output_dir)
        print(json.dumps(info, indent=2))
    
    elif args.command == "list-content":
        files = list_content_files(args.epub)
        if args.json:
            print(json.dumps(files, indent=2))
        else:
            for f in files:
                print(f"{f['id']}: {f['href']}")
    
    elif args.command == "content-files":
        files = get_content_files(args.extract_dir, args.opf_path)
        for f in files:
            print(f)
    
    elif args.command == "update-meta":
        if args.lang:
            update_metadata(
                args.extract_dir, 
                args.opf_path, 
                args.lang,
                args.title_suffix or ""
            )
    
    elif args.command == "pack":
        pack_epub(args.source_dir, args.output)


if __name__ == "__main__":
    main()
