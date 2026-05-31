import argparse
import json
import shutil
from pathlib import Path

from .augment import AUGMENTERS
from .backends import BACKENDS
from .config import read_config
from .golden import fixture_bytes, format_hex, normalize_hex, read_golden_file
from .output import preview_output_root, write_json
from .schema import build_schema


def command_extract(args):
    root = Path(args.root).resolve()
    config_path = (root / args.config).resolve()
    config = read_config(config_path)
    schema = build_schema(root, config)
    generated = root / config["schema"]["generated"]
    write_json(generated, schema)
    if args.update_snapshot:
        write_json(root / config["schema"]["snapshot"], schema)
    elif args.check_snapshot:
        snapshot_path = root / config["schema"]["snapshot"]
        if not snapshot_path.exists():
            raise SystemExit(f"Missing schema snapshot: {snapshot_path}")
        snapshot = json.loads(snapshot_path.read_text(encoding="utf-8"))
        if snapshot != schema:
            raise SystemExit("Schema snapshot is out of date")
    print(f"Wrote {generated}")


def command_generate(args):
    root = Path(args.root).resolve()
    config_path = (root / args.config).resolve()
    config = read_config(config_path)
    schema = build_schema(root, config)
    generated = root / config["schema"]["generated"]
    write_json(generated, schema)
    written = []
    for target_name, target in config.get("targets", {}).items():
        out_root = preview_output_root(root, config, target_name, target, args)
        always_write = str(target.get("always_write", "")).lower() == "true"
        if not args.write_targets and not always_write and out_root.exists():
            shutil.rmtree(out_root)
        backend = target.get("backend")
        generate = BACKENDS.get(backend)
        if generate is None:
            raise SystemExit(f"Unsupported backend for target {target_name}: {backend}")
        written.extend(generate(schema, target_name, target, out_root))
        if not args.no_augment and not args.pure:
            augment = AUGMENTERS.get(backend)
            if augment is not None:
                written.extend(augment(schema, target_name, target, out_root))
    for path in sorted(set(written)):
        print(f"Wrote {path}")


def command_golden(args):
    root = Path(args.root).resolve()
    config_path = (root / args.config).resolve()
    config = read_config(config_path)
    schema = build_schema(root, config)
    fixtures_path = (root / args.fixtures).resolve()
    data = read_golden_file(fixtures_path)
    mismatches = []
    for fixture in data["fixtures"]:
        expected = fixture.get("hex")
        actual = format_hex(fixture_bytes(schema, fixture))
        if args.update_golden:
            fixture["hex"] = actual
            continue
        if not expected:
            mismatches.append(f"{fixture.get('name', fixture.get('type', '<unnamed>'))}: missing expected hex")
            continue
        if normalize_hex(expected) != normalize_hex(actual):
            name = fixture.get("name", fixture.get("type", "<unnamed>"))
            mismatches.append(f"{name}: expected {expected}, actual {actual}")
    if args.update_golden:
        write_json(fixtures_path, data, ensure_ascii=True)
        print(f"Wrote {fixtures_path}")
        return
    if mismatches:
        raise SystemExit("Golden fixtures are out of date:\n" + "\n".join(mismatches))
    print(f"Checked {len(data['fixtures'])} golden fixtures")


def main():
    parser = argparse.ArgumentParser(description="SweetEditor protocol generator")
    parser.add_argument("command", choices=["extract", "generate", "golden"])
    parser.add_argument("--root", default=".", help="Repository root")
    parser.add_argument("--config", default="tools/se_protocol_gen/config.yml")
    parser.add_argument("--fixtures", default="tools/se_protocol_gen/fixtures/golden.json")
    parser.add_argument("--update-snapshot", action="store_true")
    parser.add_argument("--check-snapshot", action="store_true")
    parser.add_argument("--update-golden", action="store_true")
    parser.add_argument("--write-targets", action="store_true", help="Write generated code into configured platform targets")
    parser.add_argument("--no-augment", action="store_true", help="Skip generated-code augmentation")
    parser.add_argument("--pure", action="store_true", help="Alias for --no-augment")
    args = parser.parse_args()
    if args.command == "extract":
        command_extract(args)
    elif args.command == "generate":
        command_generate(args)
    elif args.command == "golden":
        command_golden(args)


if __name__ == "__main__":
    main()
