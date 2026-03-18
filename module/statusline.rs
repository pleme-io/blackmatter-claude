// Nord frost statusline for Claude Code
//
// Zero-dependency Rust binary. Reads Claude Code session JSON from stdin,
// outputs a compact ANSI-colored status line with workspace, auth mode,
// model, cost, token counts, and context usage bar.

use std::io::Read;

fn main() {
    let mut input = String::new();
    if std::io::stdin().read_to_string(&mut input).is_err() || input.is_empty() {
        return;
    }

    // ── Extract fields from session JSON ──────────────────────────
    let model_id = extract_str(&input, "id").unwrap_or_default();
    let display_name = extract_str(&input, "display_name").unwrap_or_default();
    let pct = extract_num(&input, "used_percentage").unwrap_or(0.0);
    let cost = extract_num(&input, "total_cost_usd").unwrap_or(0.0);
    let input_tokens = extract_num(&input, "total_input_tokens").unwrap_or(0.0) as u64;
    let output_tokens = extract_num(&input, "total_output_tokens").unwrap_or(0.0) as u64;

    // ── Normalize model name ──────────────────────────────────────
    let model = if !model_id.is_empty() {
        // claude-opus-4-6 → opus 4.6
        let stripped = model_id.replace("claude-", "");
        // Split at first digit boundary: "opus-4-6" → ("opus", "4-6") → "opus 4.6"
        if let Some(pos) = stripped.find(|c: char| c.is_ascii_digit()) {
            let (name, ver) = stripped.split_at(pos);
            let name = name.trim_end_matches('-');
            let ver = ver.replace('-', ".");
            // Truncate long date suffixes (4.5.20251001 → 4.5)
            let ver = if ver.len() > 5 {
                ver.split('.').take(2).collect::<Vec<_>>().join(".")
            } else {
                ver
            };
            format!("{name} {ver}")
        } else {
            stripped.replace('-', " ")
        }
    } else if !display_name.is_empty() {
        display_name.replace("Claude ", "").to_lowercase()
    } else {
        "claude".into()
    };

    // ── Context progress bar ──────────────────────────────────────
    let n = 12usize;
    let filled = ((pct * n as f64) / 100.0).round().min(n as f64) as usize;
    let empty = n - filled;

    // ── Nord frost ANSI ───────────────────────────────────────────
    let b = "\x1b[34m"; // frost blue — Nord9
    let c = "\x1b[36m"; // frost cyan — Nord8
    let d = "\x1b[90m"; // dim        — Nord3
    let w = "\x1b[37m"; // snow       — Nord5
    let g = "\x1b[32m"; // aurora green — Nord14
    let r = "\x1b[0m"; // reset

    let filled_bar = "━".repeat(filled);
    let empty_bar = "╌".repeat(empty);

    // ── Workspace + auth mode ─────────────────────────────────────
    let workspace = std::env::var("WORKSPACE").unwrap_or_default();
    let workspace_prefix = if !workspace.is_empty() {
        let auth = match workspace.as_str() {
            "pleme" => "MAX",
            _ => "API",
        };
        format!("{b}{}{r} {d}│{r} {g}{auth}{r} {d}│{r} ", workspace.to_uppercase())
    } else {
        String::new()
    };

    // ── Token counts (compact: 15k↓ 4k↑) ─────────────────────────
    let tokens = if input_tokens > 0 || output_tokens > 0 {
        format!(
            " {d}│{r} {w}{}↓ {}↑{r}",
            format_tokens(input_tokens),
            format_tokens(output_tokens)
        )
    } else {
        String::new()
    };

    // ── Cost ──────────────────────────────────────────────────────
    let cost_str = if cost > 0.001 {
        format!(" {d}│{r} {g}${cost:.2}{r}")
    } else {
        String::new()
    };

    // ── Output ────────────────────────────────────────────────────
    println!(
        "{workspace_prefix}{b}{model}{r}{cost_str}{tokens} {d}│{r} {c}{filled_bar}{d}{empty_bar}{r} {w}{pct}%{r}",
        pct = pct as u32,
    );
}

fn format_tokens(n: u64) -> String {
    if n >= 1_000_000 {
        format!("{:.1}M", n as f64 / 1_000_000.0)
    } else if n >= 1_000 {
        format!("{}k", n / 1_000)
    } else {
        n.to_string()
    }
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
