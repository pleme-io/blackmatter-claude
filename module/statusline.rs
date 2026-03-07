// Nord frost statusline for Claude Code
//
// Zero-dependency Rust binary. Reads Claude Code session JSON from stdin,
// outputs a compact ANSI-colored status line. ANSI color codes map to Nord
// palette via the terminal's color scheme.

use std::io::Read;

fn main() {
    let mut input = String::new();
    if std::io::stdin().read_to_string(&mut input).is_err() || input.is_empty() {
        return;
    }

    let model = extract_str(&input, "display_name")
        .map(|s| {
            s.replace("Claude ", "")
                .to_lowercase()
                .replace(' ', "-")
        })
        .unwrap_or_else(|| "claude".into());
    let pct = extract_num(&input, "used_percentage").unwrap_or(0.0);
    let cost = extract_num(&input, "total_cost_usd").unwrap_or(0.0);

    // Context progress bar
    let n = 12usize;
    let filled = ((pct * n as f64) / 100.0).round().min(n as f64) as usize;
    let empty = n - filled;

    // Nord frost ANSI (terminal maps these to Nord palette)
    let b = "\x1b[34m"; // frost blue — Nord9
    let c = "\x1b[36m"; // frost cyan — Nord8
    let d = "\x1b[90m"; // dim        — Nord3
    let w = "\x1b[37m"; // snow       — Nord5
    let r = "\x1b[0m"; // reset

    let filled_bar = "━".repeat(filled);
    let empty_bar = "╌".repeat(empty);

    let cost_section = if cost > 0.0 {
        format!(" {d}│{r} {c}${cost:.2}{r}")
    } else {
        String::new()
    };

    println!(
        "{b}{model}{r} {d}│{r} {c}{filled_bar}{d}{empty_bar}{r} {w}{pct}%{r}{cost_section}",
        pct = pct as u32,
    );
}

fn extract_str(json: &str, key: &str) -> Option<String> {
    let needle = format!("\"{key}\"");
    let pos = json.find(&needle)? + needle.len();
    let rest = json[pos..].trim_start().strip_prefix(':')?.trim_start();
    if rest.starts_with('"') {
        let inner = &rest[1..];
        let end = inner.find('"')?;
        Some(inner[..end].to_string())
    } else {
        None
    }
}

fn extract_num(json: &str, key: &str) -> Option<f64> {
    let needle = format!("\"{key}\"");
    let pos = json.find(&needle)? + needle.len();
    let rest = json[pos..].trim_start().strip_prefix(':')?.trim_start();
    let end = rest
        .find(|c: char| !c.is_ascii_digit() && c != '.' && c != '-')
        .unwrap_or(rest.len());
    rest[..end].parse().ok()
}
