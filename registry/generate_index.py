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
import re
import shutil
import tarfile
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

CHEVRON_SVG = (
    '<svg class="chevron" viewBox="0 0 16 16" width="16" height="16" '
    'fill="currentColor" aria-hidden="true">'
    '<path fill-rule="evenodd" d="M4.646 1.646a.5.5 0 0 1 .708 0l6 6a.5.5 0 0 1 0 '
    '.708l-6 6a.5.5 0 0 1-.708-.708L10.293 8 4.646 2.354a.5.5 0 0 1 0-.708z"/>'
    "</svg>"
)


def extract_description(content):
    """Return the first OPA METADATA description annotation in rego content, or None."""
    in_metadata = False
    for line in content.splitlines():
        stripped = line.strip()
        if stripped == "# METADATA":
            in_metadata = True
            continue
        if in_metadata:
            m = re.match(r"^# description:\s*(.+)$", stripped)
            if m:
                return m.group(1)
            if not stripped.startswith("#"):
                in_metadata = False
    return None


def extract_bundle_policies(bundle_path):
    """Return [(filename, description_or_None)] for non-test .rego files in a bundle."""
    policies = []
    try:
        with tarfile.open(bundle_path, "r:gz") as tf:
            members = sorted(
                (m for m in tf.getmembers()
                 if m.name.endswith(".rego")
                 and not m.name.endswith("_test.rego")
                 and not m.name.endswith("_validators.rego")),
                key=lambda m: Path(m.name).name,
            )
            for member in members:
                basename = Path(member.name).name
                description = None
                f = tf.extractfile(member)
                if f:
                    description = extract_description(f.read().decode("utf-8", errors="replace"))
                policies.append((basename, description))
    except Exception:
        pass
    return policies


def detail_row_html(bundle_id, policies):
    """Render a hidden <tr> listing the non-test policies for a bundle."""
    if not policies:
        return ""
    detail_id = html.escape(f"details-{bundle_id}", quote=True)
    items = []
    for filename, description in policies:
        esc_name = html.escape(filename.removesuffix(".rego"))
        if description:
            esc_desc = html.escape(description)
            items.append(
                f'                        <li><strong>{esc_name}</strong>'
                f' <span class="policy-desc">— {esc_desc}</span></li>'
            )
        else:
            items.append(f'                        <li><strong>{esc_name}</strong></li>')
    return "\n".join([
        f'            <tr class="detail-row" id="{detail_id}">',
        '                <td colspan="4">',
        '                    <ul class="policy-list">',
        "\n".join(items),
        '                    </ul>',
        '                </td>',
        '            </tr>',
    ])


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
    for name, href, size, mtime, policies in entries:
        modified = datetime.fromtimestamp(mtime, timezone.utc).isoformat().replace("+00:00", "Z")
        # Derive a stable ID from the bundle filename, e.g. "autodotes_policy"
        bundle_id = name.replace(".bundle.tar.gz", "")
        detail_id = html.escape(f"details-{bundle_id}", quote=True)
        has_policies = bool(policies)
        toggle = (
            f'                        <button class="toggle-btn" '
            f'aria-expanded="false" aria-controls="{detail_id}" '
            f'aria-label="Show policies in {html.escape(name, quote=True)}">'
            f"{CHEVRON_SVG}</button>"
        ) if has_policies else ""
        main_row = "\n".join(
            [
                "            <tr>",
                "                <td>",
                '                    <span class="file">',
                toggle,
                f'                        <img class="opa" src="{icon_src}" alt="" width="32" height="32">',
                f'                        <a href="{html.escape(href, quote=True)}">{html.escape(name)}</a>',
                "                    </span>",
                "                </td>",
                f'                <td class="size">{size} bytes</td>',
                f'                <td class="modified"><time class="local" datetime="{modified}">{modified}</time></td>',
                '                <td class="download">',
                f'                    <a href="{html.escape(href, quote=True)}" download="{html.escape(name, quote=True)}" aria-label="Download {html.escape(name, quote=True)}">{download_icon}</a>',
                "                </td>",
                "            </tr>",
            ]
        )
        detail = detail_row_html(bundle_id, policies)
        blocks.append(main_row + ("\n" + detail if detail else ""))
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
    policies = extract_bundle_policies(path)
    bundle_entries.append((path.name, path.name, st.st_size, st.st_mtime, policies))
    root_entries.append((path.name, f"bundles/{path.name}", st.st_size, st.st_mtime, policies))

(site / "index.html").write_text(
    render([(site_name, None), ("bundles", None)], root_entries, ICON_PATH.name) + "\n"
)
(bundle_dir / "index.html").write_text(
    render([(site_name, "../"), ("bundles", None)], bundle_entries, f"../{ICON_PATH.name}") + "\n"
)
print(f"Wrote {site / 'index.html'} and {bundle_dir / 'index.html'}")
