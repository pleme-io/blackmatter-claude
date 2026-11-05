#!/usr/bin/env -S blue --allow filesystem
@moduledoc """
Prints a Claude Code provider's key from its file, in the shape each helper needs.
"""

@doc """
The key held in a file's text: the text without its surrounding whitespace.
"""
def key_of(text)
  trim(text)
end

@doc """
The JSON an MCP server's headersHelper prints: the key as a bearer token.
"""
def bearer_of(text)
  json_stringify({Authorization: "Bearer #{key_of(text)}"})
end

@doc """
The output for a helper mode. An unknown mode raises, so no helper prints a wrong credential.
"""
def render(mode, text)
  if mode == "key"
    key_of(text)
  elsif mode == "bearer"
    bearer_of(text)
  else
    raise(:usage, "unknown mode #{mode}: use key or bearer")
  end
end

test "the key drops the file's trailing newline"
  assert render("key", unlines(["abc.def"])) == "abc.def"
end

test "the bearer header is the only output and holds the key"
  assert render("bearer", unlines(["abc.def"])) ==
    "{\"Authorization\":\"Bearer abc.def\"}"
end

test "an empty file gives an empty key"
  assert render("key", "") == ""
end

test "an unknown mode raises"
  assert (render("token", "abc") rescue "raised") == "raised"
end

def main()
  write_stdout(render(argv[0], read_file(argv[1])))
end
