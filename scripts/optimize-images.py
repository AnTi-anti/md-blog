from __future__ import annotations

import re
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
POSTS_DIR = ROOT / "posts"
QUALITY = 82

IMAGE_LINK_RE = re.compile(r"(!\[[^\]]*\]\()([^)]+)(\))")
RASTER_EXTENSIONS = {".png", ".jpg", ".jpeg"}


def normalize_reference(reference: str) -> str:
    return reference.strip().split("?", 1)[0].split("#", 1)[0]


def is_local_raster_reference(reference: str) -> bool:
    value = normalize_reference(reference)
    if "://" in value or value.startswith(("/", "#", "data:")):
      return False
    return Path(value).suffix.lower() in RASTER_EXTENSIONS


def resolve_reference(markdown_file: Path, reference: str) -> Path:
    cleaned = normalize_reference(reference).replace("\\", "/")
    if cleaned.startswith("imgs/"):
        cleaned = "images/" + cleaned[5:]
    return (markdown_file.parent / cleaned).resolve()


def build_rewritten_reference(reference: str) -> str:
    suffix = ""
    value = reference.strip()
    if "?" in value:
        value, suffix = value.split("?", 1)
        suffix = "?" + suffix
    elif "#" in value:
        value, suffix = value.split("#", 1)
        suffix = "#" + suffix

    normalized = value.replace("\\", "/")
    if normalized.startswith("imgs/"):
        normalized = "images/" + normalized[5:]

    base = str(Path(normalized).with_suffix(".webp")).replace("\\", "/")
    return base + suffix


def ensure_webp(source_path: Path) -> Path:
    target_path = source_path.with_suffix(".webp")
    if target_path.exists() and target_path.stat().st_mtime >= source_path.stat().st_mtime:
        return target_path

    with Image.open(source_path) as image:
        converted = image.convert("RGBA") if image.mode in {"RGBA", "LA", "P"} else image.convert("RGB")
        converted.save(target_path, format="WEBP", quality=QUALITY, method=6)

    return target_path


def collect_all_raster_sources() -> list[Path]:
    sources: set[Path] = set()
    for extension in RASTER_EXTENSIONS:
        sources.update(POSTS_DIR.rglob(f"*{extension}"))
        sources.update(POSTS_DIR.rglob(f"*{extension.upper()}"))
    return sorted(path.resolve() for path in sources if path.is_file())


def rewrite_markdown_images(markdown_file: Path) -> bool:
    content = markdown_file.read_text(encoding="utf-8")
    changed = False

    def replacer(match: re.Match[str]) -> str:
        nonlocal changed
        prefix, reference, suffix = match.groups()
        if not is_local_raster_reference(reference):
            return match.group(0)

        source_path = resolve_reference(markdown_file, reference)
        if not source_path.exists():
            return match.group(0)

        ensure_webp(source_path)
        rewritten = build_rewritten_reference(reference)
        if rewritten != reference:
            changed = True
        return f"{prefix}{rewritten}{suffix}"

    updated = IMAGE_LINK_RE.sub(replacer, content)
    if changed and updated != content:
        markdown_file.write_text(updated, encoding="utf-8")
    return changed


def main() -> int:
    markdown_files = sorted(POSTS_DIR.glob("*.md"))
    changed_files = []
    sources_to_remove = collect_all_raster_sources()
    converted_sources = []

    for source_path in sources_to_remove:
        ensure_webp(source_path)
        converted_sources.append(source_path.name)

    for markdown_file in markdown_files:
        if rewrite_markdown_images(markdown_file):
            changed_files.append(markdown_file.name)

    deleted_sources = []
    for source_path in sources_to_remove:
        target_path = source_path.with_suffix(".webp")
        if target_path.exists() and source_path.exists():
            source_path.unlink()
            deleted_sources.append(source_path.name)

    if changed_files:
        print("Optimized image references in:")
        for name in changed_files:
            print(f"  - {name}")
    else:
        print("No markdown image references needed optimization.")

    if converted_sources:
        print("Ensured WebP copies for:")
        for name in converted_sources:
            print(f"  - {name}")

    if deleted_sources:
        print("Removed original raster files:")
        for name in deleted_sources:
            print(f"  - {name}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
