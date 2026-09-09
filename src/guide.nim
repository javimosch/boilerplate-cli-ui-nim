## The embedded guide and command catalog (cli-guide-spec, cli-output-spec §4).
##
## Compiled into the binary as string constants: an agent that lands on a
## machine with this binary and no network can still learn the tool. Never
## fetched at runtime.

const
  TOOL* = "boilerplate-cli-ui-nim"
  VERSION* = "1.0.0"

const GUIDE_JSON* = """{
"boilerplate-cli-ui-nim":"A Nim CLI with an embedded web UI, compiled to one small native binary.",
"version":"1.0.0",
"one_liner":"Starts an asynchttpserver that serves a Vue 3 dashboard at / and a JSON API at /api/*, from one native binary with the UI compiled in via staticRead — no assets to deploy alongside it.",
"model":{
"binary":"one executable; staticRead pulls each ui/ file into the binary at compile time.",
"server":"std/asynchttpserver on a single async dispatcher, bound to an explicit address:port.",
"daemon":"re-execs itself as `serve`, detached, with /_health as the source of truth for liveness.",
"contract":"agent-first: data on stdout, context on stderr, semantic exit codes, typed errors, an embedded guide."
},
"loop":[
"./build.sh — nim c -d:release --opt:size",
"./boilerplate-cli-ui-nim serve — foreground on 127.0.0.1:8080",
"open http://127.0.0.1:8080/ for the UI, or curl /api/status for JSON",
"./boilerplate-cli-ui-nim daemon start — background it instead",
"./boilerplate-cli-ui-nim daemon stop — stop it"
],
"concepts":{
"embedded UI":"staticRead compiles each ui/ file into the binary. Edit the files, rebuild.",
"loopback default":"serve binds 127.0.0.1 unless --host says otherwise. Binding the whole network is deliberate.",
"shutdown token":"off-loopback, POST /_shutdown requires X-Shutdown-Token matching $SHUTDOWN_TOKEN, or it answers 403 and keeps running.",
"exit codes":"0 ok, 80-89 input, 90-99 state, 100-109 external, 110-119 internal. The code equals .error.code in the body."
},
"commands":{"server":[
"boilerplate-cli-ui-nim serve [--host H] [--port N]",
"boilerplate-cli-ui-nim daemon start [--port N]",
"boilerplate-cli-ui-nim daemon stop [--port N]",
"boilerplate-cli-ui-nim daemon status [--port N]"
],"introspection":[
"boilerplate-cli-ui-nim guide [--human]",
"boilerplate-cli-ui-nim help-json",
"boilerplate-cli-ui-nim version [--json]"
]},
"examples":[
{"goal":"serve the UI on a custom port","do":["./boilerplate-cli-ui-nim serve --port 3000"]},
{"goal":"background it and confirm it is up","do":["./boilerplate-cli-ui-nim daemon start --port 3000","./boilerplate-cli-ui-nim daemon status --port 3000"]},
{"goal":"expose it on the LAN with a kill switch that needs a token","do":["SHUTDOWN_TOKEN=s3cret ./boilerplate-cli-ui-nim serve --host 0.0.0.0 --port 8080"]}
],
"gotchas":[
"The UI is compiled in: editing ui/ does nothing until you rebuild.",
"serve binds 127.0.0.1 by default. If you expected it on the LAN, pass --host 0.0.0.0 — and then set SHUTDOWN_TOKEN, or /_shutdown answers 403 to everyone.",
"daemon start is idempotent: called twice it reports the running instance instead of racing a second process onto the port.",
"daemon stop against a stopped daemon exits 0 — a no-op success, not an error.",
"Startup lines go to stderr. An agent parsing stdout sees only data."
],
"see_also":["https://cli-specs.intrane.fr"]}"""

const GUIDE_MARKDOWN* = """# boilerplate-cli-ui-nim

A Nim CLI with an embedded web UI, compiled to one small native binary.

## Model

- One executable; the UI ships inside it through `staticRead`.
- std/asynchttpserver bound to an explicit address:port.
- The daemon re-execs itself as `serve`; /_health is liveness.
- Agent-first: data on stdout, context on stderr, semantic exit codes.

## Loop

1. `./build.sh`
2. `./boilerplate-cli-ui-nim serve`
3. Open http://127.0.0.1:8080/ or curl /api/status.
4. `./boilerplate-cli-ui-nim daemon start` to background it.
5. `./boilerplate-cli-ui-nim daemon stop` to stop it.

## Commands

- `serve [--host H] [--port N]`
- `daemon start|stop|status [--port N]`
- `guide [--human]`, `help-json`, `version [--json]`

## Gotchas

- The UI is compiled in: rebuild after editing ui/.
- `serve` binds 127.0.0.1 by default; `--host 0.0.0.0` is deliberate.
- Off-loopback, `POST /_shutdown` needs `X-Shutdown-Token` = `$SHUTDOWN_TOKEN`.
- `daemon start` twice is idempotent; `daemon stop` when stopped exits 0.
"""

const LLMS_TXT* = """# boilerplate-cli-ui-nim

A Nim CLI with an embedded web UI. One native binary.

## Drive it

    boilerplate-cli-ui-nim serve [--host H] [--port N]
    boilerplate-cli-ui-nim daemon start|stop|status [--port N]

JSON on stdout, context on stderr, exit 0/80-119.

## Learn it

    boilerplate-cli-ui-nim guide      # embedded, JSON
    boilerplate-cli-ui-nim help-json  # command catalog

HTTP: GET /  GET /api/status  GET /_health  POST /_shutdown  GET /guide
"""

const HELP_JSON* = """{
"version":"1.0","tool":"boilerplate-cli-ui-nim","tool_version":"1.0.0",
"commands":[
{"name":"serve","summary":"run the HTTP server in the foreground","flags":[
{"name":"--host","summary":"bind address","default":"127.0.0.1","env":"HOST"},
{"name":"--port","summary":"port","default":"8080","env":"PORT"}]},
{"name":"daemon start","summary":"start the server in the background (idempotent)"},
{"name":"daemon stop","summary":"stop the background server (no-op success if stopped)"},
{"name":"daemon status","summary":"report background server status"},
{"name":"guide","summary":"the embedded operator guide","flags":[{"name":"--human","summary":"markdown instead of JSON"}]},
{"name":"help-json","summary":"this machine-readable command catalog"},
{"name":"version","summary":"print the version","flags":[{"name":"--json","summary":"JSON output"}]}
],
"endpoints":[
{"method":"GET","path":"/","summary":"the embedded web UI"},
{"method":"GET","path":"/api/status","summary":"app status JSON"},
{"method":"GET","path":"/_health","summary":"liveness: {ok,service,pid}"},
{"method":"POST","path":"/_shutdown","summary":"stop the server; token-gated off-loopback"},
{"method":"GET","path":"/guide","summary":"the guide over HTTP"},
{"method":"GET","path":"/llms.txt","summary":"the short agent-facing README"}
],
"exit_codes":{
"0":"success",
"80":"missing argument or bad flag value",
"85":"unknown command",
"90":"precondition failed (port unavailable, forbidden)",
"100":"external failure (the daemon did not answer)",
"110":"internal error"
},
"env":[
{"name":"PORT","summary":"default port"},
{"name":"HOST","summary":"default bind address"},
{"name":"SHUTDOWN_TOKEN","summary":"required by POST /_shutdown when bound off-loopback"}
],
"see_also":["boilerplate-cli-ui-nim guide","https://cli-specs.intrane.fr"]}"""
