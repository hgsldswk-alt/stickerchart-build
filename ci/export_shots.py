"""Export named app screenshots directly from xcresult attachments."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
from tempfile import TemporaryDirectory

PATTERN = re.compile(r"^(store-(?:zh-Hans|zh-Hant|en)-\d{2}-[a-z-]+|paid-\d{2}-[a-z-]+)(?=[_.]|$)")
ROOT = Path(__file__).resolve().parents[1]


def expected_names():
    if not (ROOT / "上架资料" / "商店截图.json").is_file():  # 公开编译仓库不带上架资料
        return None
    config = json.loads((ROOT / "上架资料" / "商店截图.json").read_text(encoding="utf-8"))
    return {"paid-01-paywall"} | {
        f"store-{language}-{page['shot']}"
        for language in ("en", "zh-Hans", "zh-Hant")
        for page in config["pages"]
    }


def named_sources(folder):
    manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
    found = {}
    for test in manifest:
        for attachment in test.get("attachments", []):
            match = PATTERN.match(attachment.get("suggestedHumanReadableName", ""))
            source = folder / attachment["exportedFileName"]
            if match and source.suffix.lower() == ".png" and source.is_file():
                found[match[1]] = source
    return found


def export(result, output):
    output.mkdir(parents=True, exist_ok=True)
    with TemporaryDirectory(dir=output) as directory:
        folder = Path(directory)
        subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(result),
                        "--output-path", str(folder)], check=True)
        sources = named_sources(folder)
        names = expected_names()
        if names is None:
            names = set(sources)
        missing = names - sources.keys()
        if missing:
            sys.exit("缺少截图附件：" + ", ".join(sorted(missing)))
        for name in sorted(names):
            shutil.copy2(sources[name], output / f"{name}.png")
    print(f"已导出 {len(names)} 张截图到 {output}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("用法：export_shots.py <test.xcresult> <build/flow_shots>")
    export(Path(sys.argv[1]), Path(sys.argv[2]))
