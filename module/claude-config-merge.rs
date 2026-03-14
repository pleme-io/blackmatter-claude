// Claude Code config merge tool
//
// Zero-dependency Rust binary. Replaces the jq-based activation script for
// merging Nix-managed MCP server config into ~/.claude.json.
//
// Features the jq approach lacked:
//   - Validates MCP server command binaries exist on disk
//   - Removes stale entries with missing binaries (GC'd nix store paths)
//   - Atomic write (write to .tmp then rename)
//   - Clear error reporting
//
// Usage: claude-config-merge <managed-config.json> [--config <path>]
//   managed-config.json: Nix-generated JSON with { mcpServers: { ... } }
//   --config: path to claude config (default: ~/.claude.json)

use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 2 {
        eprintln!("usage: claude-config-merge <managed-config.json> [--config <path>]");
        std::process::exit(1);
    }

    let managed_path = &args[1];
    let config_path = if let Some(pos) = args.iter().position(|a| a == "--config") {
        PathBuf::from(args.get(pos + 1).unwrap_or_else(|| {
            eprintln!("error: --config requires a path argument");
            std::process::exit(1);
        }))
    } else {
        let home = std::env::var("HOME").unwrap_or_else(|_| {
            eprintln!("error: HOME not set");
            std::process::exit(1);
        });
        PathBuf::from(home).join(".claude.json")
    };

    // Read managed config (from nix store)
    let managed_raw = fs::read_to_string(managed_path).unwrap_or_else(|e| {
        eprintln!("error: cannot read managed config {managed_path}: {e}");
        std::process::exit(1);
    });
    let managed: JsonValue = parse_json(&managed_raw).unwrap_or_else(|| {
        eprintln!("error: invalid JSON in managed config {managed_path}");
        std::process::exit(1);
    });

    // Read existing config (may not exist yet)
    let existing: JsonValue = if config_path.exists() {
        let raw = fs::read_to_string(&config_path).unwrap_or_else(|e| {
            eprintln!("error: cannot read {}: {e}", config_path.display());
            std::process::exit(1);
        });
        parse_json(&raw).unwrap_or_else(|| {
            eprintln!("error: invalid JSON in {}", config_path.display());
            std::process::exit(1);
        })
    } else {
        JsonValue::Object(BTreeMap::new())
    };

    // Deep merge: managed wins over existing
    let merged = deep_merge(&existing, &managed);

    // Remove MCP servers not in the managed config (prevents stale entries
    // from old nix generations persisting after the module that created them
    // is removed). Also removes entries with missing binaries (GC'd paths).
    let cleaned = clean_stale_mcp_servers(&merged, &managed);

    // Report what changed
    report_mcp_status(&cleaned);

    // Atomic write
    let tmp_path = config_path.with_extension("json.tmp");
    let output = format_json(&cleaned);
    fs::write(&tmp_path, &output).unwrap_or_else(|e| {
        eprintln!("error: cannot write {}: {e}", tmp_path.display());
        std::process::exit(1);
    });
    fs::rename(&tmp_path, &config_path).unwrap_or_else(|e| {
        eprintln!("error: cannot rename to {}: {e}", config_path.display());
        // Clean up tmp
        let _ = fs::remove_file(&tmp_path);
        std::process::exit(1);
    });
}

fn report_mcp_status(config: &JsonValue) {
    if let JsonValue::Object(root) = config {
        if let Some(JsonValue::Object(servers)) = root.get("mcpServers") {
            if servers.is_empty() {
                eprintln!("claude-config-merge: no MCP servers configured");
                return;
            }
            for (name, entry) in servers {
                if let JsonValue::Object(obj) = entry {
                    if let Some(JsonValue::Str(cmd)) = obj.get("command") {
                        let exists = command_exists(cmd);
                        let status = if exists { "ok" } else { "MISSING" };
                        eprintln!("  {name}: {status} ({cmd})");
                    }
                }
            }
        }
    }
}

fn clean_stale_mcp_servers(config: &JsonValue, managed: &JsonValue) -> JsonValue {
    let JsonValue::Object(mut root) = config.clone() else {
        return config.clone();
    };

    // Collect the set of server names from the current managed config
    let managed_names: std::collections::HashSet<String> =
        if let JsonValue::Object(m) = managed {
            if let Some(JsonValue::Object(ms)) = m.get("mcpServers") {
                ms.keys().cloned().collect()
            } else {
                std::collections::HashSet::new()
            }
        } else {
            std::collections::HashSet::new()
        };

    if let Some(JsonValue::Object(mut servers)) = root.remove("mcpServers") {
        let stale: Vec<String> = servers
            .iter()
            .filter_map(|(name, entry)| {
                // Remove empty server entries (no command field — invalid schema)
                if let JsonValue::Object(obj) = entry {
                    if obj.is_empty() || !obj.contains_key("command") {
                        eprintln!("claude-config-merge: removing invalid server '{name}' (empty or missing command)");
                        return Some(name.clone());
                    }
                    if let Some(JsonValue::Str(cmd)) = obj.get("command") {
                        if !command_exists(cmd) {
                            eprintln!("claude-config-merge: removing stale server '{name}' (binary missing: {cmd})");
                            return Some(name.clone());
                        }
                        // Remove servers with nix store commands that aren't in the
                        // current managed config — they're from old nix generations.
                        if cmd.starts_with("/nix/store/") && !managed_names.contains(name) {
                            eprintln!("claude-config-merge: removing unmanaged nix server '{name}' (not in current config)");
                            return Some(name.clone());
                        }
                    }
                }
                None
            })
            .collect();

        for name in stale {
            servers.remove(&name);
        }

        root.insert("mcpServers".to_string(), JsonValue::Object(servers));
    }

    JsonValue::Object(root)
}

fn command_exists(cmd: &str) -> bool {
    // The command field can be a direct path or a wrapper script path
    Path::new(cmd).exists()
}

// ── Minimal JSON parser + formatter (zero deps) ──────────────────────────

#[derive(Debug, Clone, PartialEq)]
enum JsonValue {
    Null,
    Bool(bool),
    Num(String), // preserve original representation
    Str(String),
    Array(Vec<JsonValue>),
    Object(BTreeMap<String, JsonValue>),
}

fn deep_merge(base: &JsonValue, overlay: &JsonValue) -> JsonValue {
    match (base, overlay) {
        (JsonValue::Object(b), JsonValue::Object(o)) => {
            let mut result = b.clone();
            for (key, oval) in o {
                let merged = if let Some(bval) = b.get(key) {
                    deep_merge(bval, oval)
                } else {
                    oval.clone()
                };
                result.insert(key.clone(), merged);
            }
            JsonValue::Object(result)
        }
        // overlay wins for non-object types
        (_, overlay) => overlay.clone(),
    }
}

fn parse_json(input: &str) -> Option<JsonValue> {
    let trimmed = input.trim();
    let (val, _) = parse_value(trimmed)?;
    Some(val)
}

fn parse_value(s: &str) -> Option<(JsonValue, &str)> {
    let s = s.trim_start();
    if s.is_empty() {
        return None;
    }
    match s.as_bytes()[0] {
        b'"' => parse_string(s).map(|(v, r)| (JsonValue::Str(v), r)),
        b'{' => parse_object(s),
        b'[' => parse_array(s),
        b't' | b'f' => parse_bool(s),
        b'n' => parse_null(s),
        _ => parse_number(s),
    }
}

fn parse_string(s: &str) -> Option<(String, &str)> {
    if !s.starts_with('"') {
        return None;
    }
    let s = &s[1..];
    let mut result = String::new();
    let mut chars = s.chars();
    loop {
        match chars.next()? {
            '"' => {
                let rest = chars.as_str();
                return Some((result, rest));
            }
            '\\' => match chars.next()? {
                '"' => result.push('"'),
                '\\' => result.push('\\'),
                '/' => result.push('/'),
                'b' => result.push('\u{0008}'),
                'f' => result.push('\u{000c}'),
                'n' => result.push('\n'),
                'r' => result.push('\r'),
                't' => result.push('\t'),
                'u' => {
                    let hex: String = chars.by_ref().take(4).collect();
                    if hex.len() != 4 {
                        return None;
                    }
                    let cp = u32::from_str_radix(&hex, 16).ok()?;
                    if let Some(c) = char::from_u32(cp) {
                        result.push(c);
                    } else {
                        // surrogate pair — just emit replacement
                        result.push('\u{FFFD}');
                    }
                }
                _ => return None,
            },
            c => result.push(c),
        }
    }
}

fn parse_object(s: &str) -> Option<(JsonValue, &str)> {
    let s = s.strip_prefix('{')?.trim_start();
    if let Some(rest) = s.strip_prefix('}') {
        return Some((JsonValue::Object(BTreeMap::new()), rest));
    }
    let mut map = BTreeMap::new();
    let mut s = s;
    loop {
        s = s.trim_start();
        let (key, rest) = parse_string(s)?;
        s = rest.trim_start().strip_prefix(':')?;
        let (val, rest) = parse_value(s)?;
        map.insert(key, val);
        s = rest.trim_start();
        if let Some(rest) = s.strip_prefix('}') {
            return Some((JsonValue::Object(map), rest));
        }
        s = s.strip_prefix(',')?;
    }
}

fn parse_array(s: &str) -> Option<(JsonValue, &str)> {
    let s = s.strip_prefix('[')?.trim_start();
    if let Some(rest) = s.strip_prefix(']') {
        return Some((JsonValue::Array(vec![]), rest));
    }
    let mut arr = Vec::new();
    let mut s = s;
    loop {
        let (val, rest) = parse_value(s)?;
        arr.push(val);
        s = rest.trim_start();
        if let Some(rest) = s.strip_prefix(']') {
            return Some((JsonValue::Array(arr), rest));
        }
        s = s.strip_prefix(',')?;
    }
}

fn parse_bool(s: &str) -> Option<(JsonValue, &str)> {
    if let Some(rest) = s.strip_prefix("true") {
        Some((JsonValue::Bool(true), rest))
    } else if let Some(rest) = s.strip_prefix("false") {
        Some((JsonValue::Bool(false), rest))
    } else {
        None
    }
}

fn parse_null(s: &str) -> Option<(JsonValue, &str)> {
    s.strip_prefix("null").map(|rest| (JsonValue::Null, rest))
}

fn parse_number(s: &str) -> Option<(JsonValue, &str)> {
    let end = s
        .find(|c: char| !c.is_ascii_digit() && c != '.' && c != '-' && c != '+' && c != 'e' && c != 'E')
        .unwrap_or(s.len());
    if end == 0 {
        return None;
    }
    Some((JsonValue::Num(s[..end].to_string()), &s[end..]))
}

fn format_json(val: &JsonValue) -> String {
    let mut out = String::new();
    format_value(val, &mut out, 0);
    out.push('\n');
    out
}

fn format_value(val: &JsonValue, out: &mut String, indent: usize) {
    match val {
        JsonValue::Null => out.push_str("null"),
        JsonValue::Bool(b) => out.push_str(if *b { "true" } else { "false" }),
        JsonValue::Num(n) => out.push_str(n),
        JsonValue::Str(s) => {
            out.push('"');
            for c in s.chars() {
                match c {
                    '"' => out.push_str("\\\""),
                    '\\' => out.push_str("\\\\"),
                    '\n' => out.push_str("\\n"),
                    '\r' => out.push_str("\\r"),
                    '\t' => out.push_str("\\t"),
                    c if c < '\x20' => {
                        out.push_str(&format!("\\u{:04x}", c as u32));
                    }
                    c => out.push(c),
                }
            }
            out.push('"');
        }
        JsonValue::Array(arr) => {
            if arr.is_empty() {
                out.push_str("[]");
                return;
            }
            out.push_str("[\n");
            for (i, v) in arr.iter().enumerate() {
                push_indent(out, indent + 1);
                format_value(v, out, indent + 1);
                if i + 1 < arr.len() {
                    out.push(',');
                }
                out.push('\n');
            }
            push_indent(out, indent);
            out.push(']');
        }
        JsonValue::Object(map) => {
            if map.is_empty() {
                out.push_str("{}");
                return;
            }
            out.push_str("{\n");
            let len = map.len();
            for (i, (k, v)) in map.iter().enumerate() {
                push_indent(out, indent + 1);
                out.push('"');
                out.push_str(k);
                out.push_str("\": ");
                format_value(v, out, indent + 1);
                if i + 1 < len {
                    out.push(',');
                }
                out.push('\n');
            }
            push_indent(out, indent);
            out.push('}');
        }
    }
}

fn push_indent(out: &mut String, level: usize) {
    for _ in 0..level {
        out.push_str("  ");
    }
}
