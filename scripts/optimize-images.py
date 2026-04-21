from __future__ import annotations

import hashlib
import os
import re
import shutil
from pathlib import Path
from urllib.parse import unquote

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
POSTS_DIR = ROOT / "posts"
IMAGES_DIR = POSTS_DIR / "images"
QUALITY = 82

IMAGE_LINK_RE = re.compile(r"(!\[[^\]]*\]\()([^)]+)(\))")
RASTER_EXTENSIONS = {".png", ".jpg", ".jpeg"}
SUPPORTED_IMAGE_EXTENSIONS = RASTER_EXTENSIONS | {".webp"}


def unwrap_reference(reference: str) -> str:
    value = reference.strip()
    if value.startswith("<") and value.endswith(">"):
        value = value[1:-1].strip()
    return value


def split_reference_suffix(reference: str) -> tuple[str, str]:
    value = unwrap_reference(reference)
    match = re.search(r"[?#]", value)
    if not match:
        return value, ""
    return value[:match.start()], value[match.start():]


def normalize_reference(reference: str) -> str:
    base, _suffix = split_reference_suffix(reference)
    return base


def normalize_reference_path(reference: str) -> str:
    value = unquote(normalize_reference(reference)).replace("\\", "/")
    if value.lower().startswith("file:///"):
        value = value[8:]
    if value.startswith("imgs/"):
        value = "images/" + value[5:]
    return value


def is_local_absolute_path(value: str) -> bool:
    return bool(re.match(r"^[A-Za-z]:[\\/]", value))


def is_supported_local_image_reference(reference: str) -> bool:
    value = normalize_reference(reference)
    if not value or value.startswith(("#", "data:")):
        return False
    if "://" in value and not value.lower().startswith("file:///"):
        return False
    return Path(value).suffix.lower() in SUPPORTED_IMAGE_EXTENSIONS


def resolve_reference(markdown_file: Path, reference: str) -> Path:
    cleaned = normalize_reference_path(reference)
    if is_local_absolute_path(cleaned):
        return Path(cleaned).resolve()
    return (markdown_file.parent / cleaned).resolve()


def is_path_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def sanitize_stem(stem: str) -> str:
    normalized = re.sub(r"[^A-Za-z0-9]+", "-", stem).strip("-").lower()
    return normalized or "image"


def ensure_local_copy(source_path: Path, target_path: Path) -> Path:
    target_path.parent.mkdir(parents=True, exist_ok=True)
    if source_path.resolve() == target_path.resolve():
        return target_path
    if target_path.exists() and target_path.stat().st_mtime >= source_path.stat().st_mtime:
        return target_path
    shutil.copy2(source_path, target_path)
    return target_path


def ensure_webp(source_path: Path, target_path: Path | None = None) -> Path:
    target_path = target_path or source_path.with_suffix(".webp")
    target_path.parent.mkdir(parents=True, exist_ok=True)
    if target_path.exists() and target_path.stat().st_mtime >= source_path.stat().st_mtime:
        return target_path

    with Image.open(source_path) as image:
        converted = image.convert("RGBA") if image.mode in {"RGBA", "LA", "P"} else image.convert("RGB")
        converted.save(target_path, format="WEBP", quality=QUALITY, method=6)

    return target_path


def build_import_target(source_path: Path, suffix: str) -> Path:
    digest = hashlib.sha1(str(source_path).encode("utf-8")).hexdigest()[:10]
    file_name = f"{sanitize_stem(source_path.stem)}-{digest}{suffix}"
    return IMAGES_DIR / file_name


def get_repo_asset_target(source_path: Path) -> Path:
    source_suffix = source_path.suffix.lower()
    if is_path_within(source_path, POSTS_DIR):
        relative_path = source_path.resolve().relative_to(POSTS_DIR.resolve()).as_posix()
        normalized_relative = relative_path
        if normalized_relative.startswith("imgs/"):
            normalized_relative = "images/" + normalized_relative[5:]
        target_path = POSTS_DIR / Path(normalized_relative)
        if source_suffix in RASTER_EXTENSIONS:
            return ensure_webp(source_path, target_path.with_suffix(".webp"))
        return ensure_local_copy(source_path, target_path)

    if source_suffix in RASTER_EXTENSIONS:
        return ensure_webp(source_path, build_import_target(source_path, ".webp"))
    return ensure_local_copy(source_path, build_import_target(source_path, source_suffix))


def build_rewritten_reference(markdown_file: Path, target_path: Path, reference: str) -> str:
    _base, suffix = split_reference_suffix(reference)
    relative_path = os.path.relpath(target_path, start=markdown_file.parent).replace("\\", "/")
    return relative_path + suffix


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
        if not is_supported_local_image_reference(reference):
            return match.group(0)

        source_path = resolve_reference(markdown_file, reference)
        if not source_path.exists():
            return match.group(0)

        rewritten = build_rewritten_reference(markdown_file, get_repo_asset_target(source_path), reference)
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
