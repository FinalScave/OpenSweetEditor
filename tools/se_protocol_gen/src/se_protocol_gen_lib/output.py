import json
from pathlib import Path


def write_json(path, data, ensure_ascii=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=ensure_ascii) + "\n", encoding="utf-8")

def preview_output_root(root, config, target_name, target, args):
    if str(target.get("always_write", "")).lower() == "true":
        return root / target.get("output_root", ".")
    if args.write_targets:
        return root / target["output_root"]
    preview_root = root / config.get("codegen", {}).get("preview_root", "tools/se_protocol_gen/generated/preview")
    return preview_root / target_name

