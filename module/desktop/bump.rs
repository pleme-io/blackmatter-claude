// claude-desktop-bump — refresh module/desktop/pin.json to Anthropic's
// current macOS release.
//
// Anthropic publishes no stable "latest" download URL — every build is a
// versioned zip named by its content hash — so the pin must be rewritten, and
// a `nix flake update` of this repo is the upgrade path only after this runs.
//
// Zero dependencies, compiled with bare `rustc` like its siblings. All network
// I/O goes through `nix store prefetch-file`, so the recorded hash is the one
// Nix itself computed.
//
// Usage (repo root): claude-desktop-bump [pin-path]
// Exit: 0 = pin current or updated; 1 = error.

use std::process::Command;

const FEED: &str = "https://downloads.claude.ai/releases/darwin/universal/RELEASES.json";
const DEFAULT_PIN: &str = "module/desktop/pin.json";

fn main() {
    let pin_path = std::env::args().nth(1).unwrap_or_else(|| DEFAULT_PIN.to_string());
    if let Err(e) = run(&pin_path) {
        eprintln!("claude-desktop-bump: {e}");
        std::process::exit(1);
    }
}

fn run(pin_path: &str) -> Result<(), String> {
    let feed = prefetch(FEED)?;
    let feed_json = std::fs::read_to_string(&feed.store_path)
        .map_err(|e| ["cannot read feed ", &feed.store_path, ": ", &e.to_string()].concat())?;
    let (version, url) = current_release(&feed_json)?;

    let pin = std::fs::read_to_string(pin_path).unwrap_or_default();
    if string_field(&pin, "version").as_deref() == Some(version.as_str()) {
        println!("claude-desktop: {version} is current");
        return Ok(());
    }

    let zip = prefetch(&url)?;
    let out = ["{\n  \"version\": \"", &version, "\",\n  \"url\": \"", &url, "\",\n  \"hash\": \"", &zip.hash, "\"\n}\n"].concat();
    std::fs::write(pin_path, out).map_err(|e| ["cannot write ", pin_path, ": ", &e.to_string()].concat())?;
    println!("claude-desktop: pinned {version}");
    Ok(())
}

struct Prefetched {
    hash: String,
    store_path: String,
}

fn prefetch(url: &str) -> Result<Prefetched, String> {
    let out = Command::new("nix")
        .args(["store", "prefetch-file", "--json", url])
        .output()
        .map_err(|e| ["cannot run nix: ", &e.to_string()].concat())?;
    if !out.status.success() {
        return Err(["prefetch failed for ", url, ": ", String::from_utf8_lossy(&out.stderr).trim()].concat());
    }
    let json = String::from_utf8_lossy(&out.stdout);
    Ok(Prefetched {
        hash: string_field(&json, "hash").ok_or("prefetch output lacks `hash`")?,
        store_path: string_field(&json, "storePath").ok_or("prefetch output lacks `storePath`")?,
    })
}

// The feed lists releases; take the one whose version equals `currentRelease`.
fn current_release(feed: &str) -> Result<(String, String), String> {
    let current = string_field(feed, "currentRelease").ok_or("feed lacks `currentRelease`")?;
    let marker = ["\"version\":\"", &current, "\""].concat();
    let at = feed.find(&marker).ok_or("feed has no entry for currentRelease")?;
    let url = string_field(&feed[at..], "url").ok_or("current release lacks `url`")?;
    Ok((current, url))
}

// First `"key": "value"` string field at or after the start of `s`.
fn string_field(s: &str, key: &str) -> Option<String> {
    let needle = ["\"", key, "\""].concat();
    let rest = &s[s.find(&needle)? + needle.len()..];
    let rest = rest.trim_start().strip_prefix(':')?.trim_start().strip_prefix('"')?;
    Some(rest[..rest.find('"')?].to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    const FEED_FIXTURE: &str = r#"{"currentRelease":"2.0.1","releases":[{"version":"2.0.0","updateTo":{"url":"https://x/old.zip"}},{"version":"2.0.1","updateTo":{"name":"Claude 2.0.1","version":"2.0.1","url":"https://x/new.zip"}}]}"#;

    #[test]
    fn picks_the_current_release_not_the_first() {
        let (v, u) = current_release(FEED_FIXTURE).unwrap();
        assert_eq!(v, "2.0.1");
        assert_eq!(u, "https://x/new.zip");
    }

    #[test]
    fn reads_pretty_printed_pin() {
        let pin = "{\n  \"version\": \"2.0.1\",\n  \"hash\": \"sha256-a=\"\n}";
        assert_eq!(string_field(pin, "version").as_deref(), Some("2.0.1"));
        assert_eq!(string_field(pin, "hash").as_deref(), Some("sha256-a="));
    }

    #[test]
    fn missing_current_entry_is_an_error() {
        assert!(current_release(r#"{"currentRelease":"9","releases":[]}"#).is_err());
    }
}
