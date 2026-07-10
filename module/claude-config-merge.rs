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

    // Report and validate
    let valid = report_mcp_status(&cleaned);
    if !valid {
        eprintln!("claude-config-merge: WARNING: config has invalid MCP entries (see above)");
    }

    // Atomic write. Use explicit `.tmp` suffix construction rather than
    // `with_extension` — the latter has dotfile quirks (e.g. `.claude.json`
    // has file_stem=".claude" extension="json", which can produce surprising
    // tmp paths and intermittent ENOENT on rename when another process
    // (Spotlight/antivirus) touches the tmp before we do).
    let tmp_path = {
        let mut s = config_path.clone().into_os_string();
        s.push(".tmp");
        PathBuf::from(s)
    };
    let output = format_json(&cleaned);
    fs::write(&tmp_path, &output).unwrap_or_else(|e| {
        eprintln!("error: cannot write {}: {e}", tmp_path.display());
        std::process::exit(1);
    });
    if let Err(e) = fs::rename(&tmp_path, &config_path) {
        // Rename failure is recoverable — the existing config is intact
        // (rename is atomic on the same filesystem), and the merged content
        // is recomputable next activation. Log + clean up + exit 0 so HM
        // activation continues.
        eprintln!(
            "claude-config-merge: WARNING: cannot rename {} -> {}: {e}",
            tmp_path.display(),
            config_path.display()
        );
        eprintln!(
            "claude-config-merge: existing config at {} is unchanged; will retry next activation",
            config_path.display()
        );
        let _ = fs::remove_file(&tmp_path);
    }
}

fn report_mcp_status(config: &JsonValue) -> bool {
    let mut all_valid = true;
    if let JsonValue::Object(root) = config {
        if let Some(JsonValue::Object(servers)) = root.get("mcpServers") {
            if servers.is_empty() {
                eprintln!("claude-config-merge: no MCP servers configured");
                return true;
            }
            for (name, entry) in servers {
                if let JsonValue::Object(obj) = entry {
                    if obj.is_empty() {
                        eprintln!("  {name}: INVALID (empty entry — no command/type)");
                        all_valid = false;
                        continue;
                    }
                    if !obj.contains_key("command") && !obj.contains_key("url") {
                        eprintln!("  {name}: INVALID (missing command or url)");
                        all_valid = false;
                        continue;
                    }
                    if let Some(JsonValue::Str(cmd)) = obj.get("command") {
                        let exists = command_exists(cmd);
                        let status = if exists { "ok" } else { "MISSING" };
                        if !exists {
                            all_valid = false;
                        }
                        eprintln!("  {name}: {status} ({cmd})");
                    } else if let Some(JsonValue::Str(url)) = obj.get("url") {
                        eprintln!("  {name}: ok ({url})");
                    }
                } else {
                    eprintln!("  {name}: INVALID (not an object)");
                    all_valid = false;
                }
            }
        }
    }
    all_valid
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
    // The command field is either a literal filesystem path (direct path or
    // wrapper script path) or a bare command name meant to be resolved
    // through $PATH (e.g. `npx`, `uvx`) — exactly how a shell resolves
    // argv[0]. Mirror that: a name containing a path separator is used
    // literally; a bare name is searched for across every $PATH directory.
    // This is the same resolution algorithm `which` and most shells use.
    if cmd.contains(std::path::MAIN_SEPARATOR) {
        return Path::new(cmd).exists();
    }
    let path_var = std::env::var_os("PATH").unwrap_or_default();
    resolve_in_path(cmd, &path_var).is_some()
}

/// Search `path_var` (a `$PATH`-shaped value, platform-delimited per
/// `std::env::split_paths`) for an executable file named `cmd`. Split out
/// from `command_exists` so tests can supply a synthetic PATH without
/// mutating real process environment (env vars are process-global and
/// mutating them is racy across parallel test threads).
fn resolve_in_path(cmd: &str, path_var: &std::ffi::OsStr) -> Option<PathBuf> {
    std::env::split_paths(path_var)
        .map(|dir| dir.join(cmd))
        .find(|candidate| is_executable_file(candidate))
}

fn is_executable_file(path: &Path) -> bool {
    // `fs::metadata` follows symlinks (PATH entries are frequently symlinks,
    // e.g. into a nix profile or store), unlike `symlink_metadata`.
    let Ok(metadata) = fs::metadata(path) else {
        return false;
    };
    if !metadata.is_file() {
        return false;
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        metadata.permissions().mode() & 0o111 != 0
    }
    #[cfg(not(unix))]
    {
        true
    }
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

// ── Tests ──────────────────────────────────────────────────────────────
//
// This binary is compiled directly via `rustc` (no Cargo.toml — see the
// zero-dependency note at the top of this file), so there is no `cargo
// test`. Build + run this module's tests with:
//
//   rustc --edition 2021 --test -o /tmp/claude-config-merge-test module/claude-config-merge.rs
//   /tmp/claude-config-merge-test

#[cfg(test)]
mod tests {
    use super::*;
    use std::ffi::OsString;
    use std::fs;
    use std::os::unix::fs::PermissionsExt;

    /// Create `dir/name` as an executable file (mode 0o755) and return its path.
    fn make_executable(dir: &Path, name: &str) -> PathBuf {
        let path = dir.join(name);
        fs::write(&path, "#!/bin/sh\n").unwrap();
        let mut perms = fs::metadata(&path).unwrap().permissions();
        perms.set_mode(0o755);
        fs::set_permissions(&path, perms).unwrap();
        path
    }

    /// Unique scratch dir per test so parallel test threads never collide.
    fn scratch_dir(label: &str) -> PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "claude-config-merge-test-{label}-{}-{:?}",
            std::process::id(),
            std::thread::current().id()
        ));
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn absolute_path_that_exists_is_found() {
        let dir = scratch_dir("abs-exists");
        let bin = make_executable(&dir, "literal-cmd");
        assert!(command_exists(bin.to_str().unwrap()));
        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn absolute_path_that_is_missing_is_not_found() {
        // Backward-compat: an absolute/relative path that doesn't exist on
        // disk must still report false, same as before this fix.
        assert!(!command_exists(
            "/definitely/not/a/real/path/claude-config-merge-test-missing"
        ));
    }

    #[test]
    fn bare_command_resolved_via_synthetic_path_is_found() {
        // The core regression this fix closes: a bare PATH-resolved command
        // name (e.g. `npx`, `uvx`) — not a literal filesystem path — must
        // resolve to true when it exists somewhere on $PATH.
        let dir = scratch_dir("path-found");
        make_executable(&dir, "npx-like-tool");
        let synthetic_path = OsString::from(dir.as_os_str());
        assert!(resolve_in_path("npx-like-tool", &synthetic_path).is_some());
        assert!(!"npx-like-tool".contains(std::path::MAIN_SEPARATOR));
        fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn bare_command_not_present_on_any_path_dir_is_not_found() {
        let synthetic_path = OsString::from("/nonexistent/dir/one:/nonexistent/dir/two");
        assert!(resolve_in_path(
            "totally-nonexistent-command-claude-config-merge-xyz",
            &synthetic_path
        )
        .is_none());
    }

    #[test]
    fn bare_command_skips_non_executable_match_and_finds_the_real_one() {
        // A same-named non-executable file earlier on PATH must not shadow
        // a real executable later on PATH (mirrors shell/`which` semantics).
        let empty_dir = scratch_dir("path-non-exec");
        let real_dir = scratch_dir("path-real");
        let decoy = empty_dir.join("shadowed-tool");
        fs::write(&decoy, "not executable").unwrap();
        make_executable(&real_dir, "shadowed-tool");

        let synthetic_path = std::env::join_paths([&empty_dir, &real_dir]).unwrap();
        let found = resolve_in_path("shadowed-tool", &synthetic_path);
        assert_eq!(found.as_deref(), Some(real_dir.join("shadowed-tool").as_path()));

        fs::remove_dir_all(&empty_dir).ok();
        fs::remove_dir_all(&real_dir).ok();
    }

    #[test]
    fn bare_command_via_real_process_path_env_still_works() {
        // Integration-style check against the real $PATH: `sh` is present on
        // every Unix CI runner / dev machine in this fleet (macOS + NixOS).
        assert!(command_exists("sh"));
    }

    #[test]
    fn genuinely_nonexistent_bare_command_is_not_found() {
        assert!(!command_exists(
            "totally-nonexistent-command-claude-config-merge-xyz"
        ));
    }
}
