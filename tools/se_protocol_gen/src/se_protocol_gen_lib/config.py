def parse_scalar(value):
    value = value.strip()
    if len(value) >= 2 and value[0] in ("'", '"') and value[-1] == value[0]:
        return value[1:-1]
    return value

def split_key_value(text):
    key, value = text.split(":", 1)
    return key.strip(), parse_scalar(value)

def read_config(config_path):
    config = {"schema": {"inputs": []}, "codegen": {}, "targets": {}}
    section = None
    target = None
    map_key = None
    for raw in config_path.read_text(encoding="utf-8").splitlines():
        line = raw.split("#", 1)[0].rstrip()
        stripped = line.strip()
        if not stripped:
            continue
        indent = len(line) - len(line.lstrip(" "))
        if indent == 0 and stripped.endswith(":"):
            section = stripped[:-1]
            target = None
            map_key = None
            continue
        if section == "schema":
            if indent == 2 and stripped == "inputs:":
                map_key = "schema.inputs"
                continue
            if indent == 4 and map_key == "schema.inputs" and stripped.startswith("- "):
                config["schema"]["inputs"].append(parse_scalar(stripped[2:]))
                continue
            if indent == 2 and ":" in stripped:
                key, value = split_key_value(stripped)
                config["schema"][key] = value
                map_key = None
            continue
        if section == "codegen":
            if indent == 2 and ":" in stripped:
                key, value = split_key_value(stripped)
                config["codegen"][key] = value
            continue
        if section == "targets":
            if indent == 2 and stripped.endswith(":"):
                target = stripped[:-1]
                config["targets"][target] = {}
                map_key = None
                continue
            if target is None:
                continue
            current = config["targets"][target]
            if indent == 4 and stripped in ("domains:", "java_api:"):
                key = stripped[:-1]
                current[key] = {}
                map_key = f"target.{key}"
                continue
            if indent == 4 and ":" in stripped:
                key, value = split_key_value(stripped)
                current[key] = value
                map_key = None
                continue
            if indent == 6 and map_key and map_key.startswith("target.") and ":" in stripped:
                key, value = split_key_value(stripped)
                current[map_key.split(".", 1)[1]][key] = value
                continue
    return config

