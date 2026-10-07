#!/usr/bin/env python3
"""Generate the GitHub Pages index pages for the OPA bundle registry.

Invoked by the "Write Pages index" step in `.github/workflows/bundle.yaml`
after bundles have been built/fetched into `_site/bundles/`. Renders two
listing pages from `template.html`:

  - `_site/index.html`          (root: links into `bundles/`)
  - `_site/bundles/index.html`  (lists each `*.bundle.tar.gz` file)

The OPA icon (`assets/opa-icon.png`) is copied into `_site/` so it can be
referenced as a normal relative path instead of being embedded as a base64
data URI in the HTML. The home and download icons (`assets/home-icon.svg`,
`assets/download-icon.svg`) are inlined directly into the rendered HTML
markup.

Environment variables:
  PAGES_BASE - Base URL the site is published at, e.g.
               https://zjleblanc.github.io/autodotes-policy
"""
import html
import os
import shutil
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse

SCRIPT_DIR = Path(__file__).resolve().parent
ASSETS_DIR = SCRIPT_DIR / "assets"
TEMPLATE_PATH = SCRIPT_DIR / "template.html"
ICON_PATH = ASSETS_DIR / "opa-icon.png"
DOWNLOAD_ICON_PATH = ASSETS_DIR / "download-icon.svg"
HOME_ICON_PATH = ASSETS_DIR / "home-icon.svg"

document = TEMPLATE_PATH.read_text()

site = Path("_site")
bundle_dir = site / "bundles"
files = sorted(
    p for p in bundle_dir.iterdir()
    if p.is_file() and p.name.endswith(".bundle.tar.gz")
)

root = urlparse(os.environ["PAGES_BASE"]).path
if not root.endswith("/"):
    root += "/"
site_name = root.strip("/") or "index"

# Copy the OPA icon into the Pages output so both listing pages can
# reference it via a relative path.
shutil.copyfile(ICON_PATH, site / ICON_PATH.name)

download_icon = DOWNLOAD_ICON_PATH.read_text().strip()
home_icon = HOME_ICON_PATH.read_text().strip()


def crumb_body(label, home):
    if not home:
        return html.escape(label)
    return f'{home_icon}<span class="clip">{html.escape(label)}</span>'


def crumbs_html(crumbs):
    parts = []
    for index, (label, href) in enumerate(crumbs):
        last = index == len(crumbs) - 1
        body = crumb_body(label, index == 0)
        if last:
            parts.append(
                f'            <li class="crumb current" aria-current="page">{body}</li>'
            )
        elif not href:
            parts.append(f'            <li class="crumb">{body}</li>')
        else:
            parts.append(
                '            <li class="crumb">'
                f'<a href="{html.escape(href, quote=True)}" aria-label="{html.escape(label, quote=True)}">{body}</a></li>'
            )
    return "\n".join(parts)


def rows_html(entries, icon_href):
    icon_src = html.escape(icon_href, quote=True)
    blocks = []
    for name, href, size, mtime in entries:
        modified = datetime.fromtimestamp(mtime, timezone.utc).isoformat().replace("+00:00", "Z")
        blocks.append(
            "\n".join(
                [
                    "            <tr>",
                    "                <td>",
                    '                    <span class="file">',
                    f'                        <img class="opa" src="{icon_src}" alt="" width="32" height="32">',
                    f'                        <a href="{html.escape(href, quote=True)}">{html.escape(name)}</a>',
                    "                    </span>",
                    "                </td>",
                    f'                <td class="size">{size} bytes</td>',
                    f'                <td class="modified"><time class="local" datetime="{modified}">{modified}</time></td>',
                    "                <td class=\"download\">",
                    f'                    <a href="{html.escape(href, quote=True)}" download="{html.escape(name, quote=True)}" aria-label="Download {html.escape(name, quote=True)}">{download_icon}</a>',
                    "                </td>",
                    "            </tr>",
                ]
            )
        )
    return "\n".join(blocks)


def render(crumbs, entries, icon_href):
    title = " / ".join(label for label, _ in crumbs)
    return (
        document.replace("@@TITLE@@", html.escape(title))
        .replace("@@CRUMBS@@", crumbs_html(crumbs))
        .replace("@@ROWS@@", rows_html(entries, icon_href))
    )


bundle_entries = []
root_entries = []
for path in files:
    st = path.stat()
    bundle_entries.append((path.name, path.name, st.st_size, st.st_mtime))
    root_entries.append((path.name, f"bundles/{path.name}", st.st_size, st.st_mtime))

(site / "index.html").write_text(
    render([(site_name, None), ("bundles", None)], root_entries, ICON_PATH.name) + "\n"
)
(bundle_dir / "index.html").write_text(
    render([(site_name, "../"), ("bundles", None)], bundle_entries, f"../{ICON_PATH.name}") + "\n"
)
print(f"Wrote {site / 'index.html'} and {bundle_dir / 'index.html'}")
