#!/usr/bin/env -S blue --allow filesystem,process
@moduledoc """
Hands a Claude Code provider's key from its file to what needs it: printed in the
shape each helper wants, or set in one variable of a command it runs.
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
    raise(:usage, "unknown mode #{mode}: use key, bearer or exec")
  end
end

@doc """
The environment a command started by exec mode gets: one variable holding the key.
"""
def env_of(name, text)
  [[name, key_of(text)]]
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

test "exec mode sets only the named variable, to the trimmed key"
  assert env_of("Z_AI_API_KEY", unlines(["abc.def"])) ==
    [%w[Z_AI_API_KEY abc.def]]
end

def main()
  if argv[0] == "exec"
    exec_into(env_of(argv[2], read_file(argv[1])), argv[3], *drop(4, argv))
  else
    write_stdout(render(argv[0], read_file(argv[1])))
  end
end
