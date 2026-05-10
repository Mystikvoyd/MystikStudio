"""
Write-LoraReport.py
Called by Start-LoraTester.ps1 to build a self-contained HTML session report.
All file I/O and base64 embedding is done here - zero PowerShell path corruption.

Usage:
    python Write-LoraReport.py <json_data_file> <output_html_file>

The JSON data file contains:
{
  "generated": "2026-05-09 04:00:00",
  "entries": [
    {
      "time": "2026-05-09 04:00:00",
      "image_path": "C:\\Users\\...\\output\\lora_test_abc.png",
      "lora_name": "my_character_v1",
      "lora_strength": 0.8,
      "lora_enabled": true,
      "seed": 1234567890,
      "steps": 30,
      "cfg": 7.0,
      "width": 1024,
      "height": 1024,
      "sampler": "dpmpp_2m",
      "prompt": "RAW photo, ...",
      "negative": "bad anatomy, ..."
    }
  ]
}
"""

import sys
import json
import base64
import os
from datetime import datetime


def embed_image(image_path):
    """Read image file and return a base64 data URI, or an error message."""
    if not image_path:
        return None, "No image path provided"
    
    # Normalize the path (handles any weird slashes)
    image_path = os.path.normpath(image_path)
    
    if not os.path.isfile(image_path):
        return None, "File not found: " + image_path
    
    try:
        with open(image_path, "rb") as f:
            data = f.read()
        b64 = base64.b64encode(data).decode("ascii")
        ext = os.path.splitext(image_path)[1].lower()
        mime = {
            ".png": "image/png",
            ".jpg": "image/jpeg",
            ".jpeg": "image/jpeg",
            ".webp": "image/webp"
        }.get(ext, "image/png")
        return "data:" + mime + ";base64," + b64, None
    except Exception as e:
        return None, "Read error: " + str(e)


def escape_html(text):
    if not text:
        return ""
    return (str(text)
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;"))


def build_html(data):
    entries = data.get("entries", [])
    generated = escape_html(data.get("generated", datetime.now().strftime("%Y-%m-%d %H:%M:%S")))
    count = len(entries)

    cards_html = ""
    for e in entries:
        img_src, img_err = embed_image(e.get("image_path", ""))
        
        if img_src:
            img_tag = '<img src="' + img_src + '" alt="Generated image">'
        else:
            img_tag = '<p class="no-img">&#x26A0; ' + escape_html(img_err) + '</p>'

        lora_enabled = e.get("lora_enabled", False)
        lora_name = escape_html(e.get("lora_name", "None"))
        lora_strength = e.get("lora_strength", 0)
        
        if lora_enabled:
            lora_badge = '<span class="badge lora-on">LoRA ON</span> ' + lora_name + ' &nbsp;<span class="strength">@ ' + str(lora_strength) + '</span>'
        else:
            lora_badge = '<span class="badge lora-off">LoRA OFF</span>'

        seed_val = e.get("seed", "random")
        if seed_val == -1 or seed_val is None:
            seed_display = "random"
        else:
            seed_display = escape_html(str(seed_val))

        cards_html += """
        <div class="entry">
          <div class="entry-img">""" + img_tag + """</div>
          <div class="entry-meta">
            <div class="entry-time">""" + escape_html(e.get("time", "")) + """</div>
            <table class="meta-table">
              <tr><th>LoRA</th><td>""" + lora_badge + """</td></tr>
              <tr><th>Seed</th><td>""" + seed_display + """</td></tr>
              <tr><th>Steps</th><td>""" + escape_html(str(e.get("steps", ""))) + """</td></tr>
              <tr><th>CFG</th><td>""" + escape_html(str(e.get("cfg", ""))) + """</td></tr>
              <tr><th>Size</th><td>""" + escape_html(str(e.get("width", ""))) + " &times; " + escape_html(str(e.get("height", ""))) + """</td></tr>
              <tr><th>Sampler</th><td>""" + escape_html(e.get("sampler", "")) + """</td></tr>
              <tr><th>Prompt</th><td class="prompt-cell">""" + escape_html(e.get("prompt", "")) + """</td></tr>
              <tr><th>Negative</th><td class="prompt-cell">""" + escape_html(e.get("negative", "")) + """</td></tr>
              <tr><th>File</th><td class="file-path">""" + escape_html(e.get("image_path", "")) + """</td></tr>
            </table>
          </div>
        </div>"""

    html = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>LoRA Test Session Report</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: "Segoe UI", sans-serif;
      background: #111116;
      color: #e0ddd8;
      padding: 32px;
    }
    h1 {
      font-size: 1.5rem;
      font-weight: 700;
      margin-bottom: 6px;
      color: #f0ece4;
      letter-spacing: 0.02em;
    }
    .session-meta {
      font-size: 0.82rem;
      color: #666;
      margin-bottom: 36px;
    }
    .entry {
      display: grid;
      grid-template-columns: 380px 1fr;
      gap: 28px;
      background: #1c1c24;
      border: 1px solid #2a2a38;
      border-radius: 12px;
      padding: 22px;
      margin-bottom: 28px;
    }
    .entry-img img {
      width: 100%;
      height: auto;
      border-radius: 8px;
      display: block;
      border: 1px solid #333;
    }
    .no-img {
      color: #c0392b;
      font-size: 0.83rem;
      padding: 12px;
      background: #2a1a1a;
      border-radius: 6px;
      border: 1px solid #5a2020;
    }
    .entry-time {
      font-size: 0.78rem;
      color: #666;
      margin-bottom: 14px;
      letter-spacing: 0.04em;
    }
    .meta-table {
      width: 100%;
      border-collapse: collapse;
      font-size: 0.87rem;
    }
    .meta-table th {
      text-align: left;
      width: 72px;
      padding: 5px 12px 5px 0;
      color: #888;
      vertical-align: top;
      white-space: nowrap;
      font-weight: 600;
    }
    .meta-table td {
      padding: 5px 0;
      color: #ccc;
      vertical-align: top;
    }
    .prompt-cell {
      white-space: pre-wrap;
      word-break: break-word;
      color: #b0aa9e;
      font-size: 0.82rem;
      line-height: 1.5;
    }
    .file-path {
      font-size: 0.75rem;
      color: #555;
      word-break: break-all;
      font-family: "Consolas", monospace;
    }
    .badge {
      display: inline-block;
      font-size: 0.7rem;
      font-weight: 800;
      padding: 2px 8px;
      border-radius: 4px;
      margin-right: 6px;
      vertical-align: middle;
      letter-spacing: 0.05em;
    }
    .lora-on  { background: #1a3d2a; color: #5ef09a; border: 1px solid #2a6040; }
    .lora-off { background: #3d1a1a; color: #f07070; border: 1px solid #602a2a; }
    .strength { color: #888; font-size: 0.83rem; }
  </style>
</head>
<body>
  <h1>LoRA Test Session Report</h1>
  <div class="session-meta">Generated: """ + generated + """ &nbsp;&middot;&nbsp; """ + str(count) + """ generation(s)</div>
""" + cards_html + """
</body>
</html>"""
    return html


def main():
    if len(sys.argv) < 3:
        print("Usage: python Write-LoraReport.py <json_data_file> <output_html_file>")
        sys.exit(1)

    json_file = sys.argv[1]
    out_file  = sys.argv[2]

    # Read the JSON data file
    with open(json_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    html = build_html(data)

    # Write the HTML using UTF-8, no BOM
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(html)

    print("Report written to: " + out_file)
    print("Entries: " + str(len(data.get("entries", []))))


if __name__ == "__main__":
    main()
