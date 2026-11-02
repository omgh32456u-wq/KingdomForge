class_name SaveSystem
extends RefCounted
## Local JSON save file in user:// (works offline on desktop and Android).

const PATH := "user://kingdomforge_save.json"

static func exists() -> bool:
    return FileAccess.file_exists(PATH)

static func write(data: Dictionary) -> bool:
    var f := FileAccess.open(PATH, FileAccess.WRITE)
    if f == null:
        return false
    f.store_string(JSON.stringify(data))
    f.close()
    return true

static func read() -> Dictionary:
    if not exists():
        return {}
    var f := FileAccess.open(PATH, FileAccess.READ)
    if f == null:
        return {}
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    f.close()
    if parsed is Dictionary:
        return parsed
    return {}
