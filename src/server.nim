## boilerplate-cli-ui-nim — a Nim CLI with an embedded web UI.
##
## The command surface follows the agent-first CLI specs
## (https://cli-specs.intrane.fr):
##   cli-output-spec  data on stdout, context on stderr, exit codes 80-119,
##                    typed errors, help-json
##   cli-guide-spec   `guide`, embedded in the binary
##   cli-daemon-spec  `serve --host --port`, /_health, /_shutdown,
##                    `daemon start|stop|status`

import std/[asynchttpserver, asyncdispatch, json, strutils, times, os]
import std/httpclient
import guide

# Embed UI files at compile time
const INDEX_HTML = staticRead("ui/index.html")
const APP_JS = staticRead("ui/js/app.js")
const STYLES_CSS = staticRead("ui/css/styles.css")

# Components
const APPLAYOUT_JS = staticRead("ui/js/components/AppLayout.js")
const SIDEBAR_JS = staticRead("ui/js/components/Sidebar.js")
const STATUSCARD_JS = staticRead("ui/js/components/StatusCard.js")

# Views
const DASHBOARD_JS = staticRead("ui/js/views/Dashboard.js")
const SETTINGS_JS = staticRead("ui/js/views/Settings.js")

# Semantic exit codes (cli-output-spec §2).
const
  ExitMissingArg = 80
  ExitUnknownCommand = 85
  ExitPrecondition = 90
  ExitExternal = 100

const
  PidFile = "/tmp/boilerplate-cli-ui-nim.pid"
  LogFile = "/tmp/boilerplate-cli-ui-nim.log"
  DefaultPort = 8080
  DefaultHost = "127.0.0.1"

var startTime = now()

## What the server actually bound. /_shutdown is token-gated whenever the host
## is not loopback (cli-daemon-spec §3).
##
## The bound host is kept as a bool rather than the string it came from:
## asynchttpserver needs a gcsafe callback, and a handler that reads a
## module-level string global is not gcsafe. The only question ever asked of
## the host is whether it is loopback, and a bool is a value type.
var boundLoopback = true
var boundPort = DefaultPort

# ─── Output helpers ─────────────────────────────────────────────

proc emit(node: JsonNode) =
  echo $node

## Emits a typed error on stdout and exits with the matching code. The exit
## status and .error.code are the same number by construction (§2, §3).
proc die(code: int, etype, message, suggestion: string) {.noreturn.} =
  emit(%*{
    "ok": false,
    "error": {
      "code": code,
      "type": etype,
      "message": message,
      "recoverable": code >= 100 and code <= 109,
      "suggestions": [suggestion]
    }
  })
  quit(code)

proc formatUptime(): string =
  let elapsed = now() - startTime
  let seconds = elapsed.inSeconds
  let hours = seconds div 3600
  let minutes = (seconds mod 3600) div 60
  let secs = seconds mod 60

  if hours > 0:
    return $hours & "h" & $minutes & "m" & $secs & "s"
  elif minutes > 0:
    return $minutes & "m" & $secs & "s"
  else:
    return $secs & "s"

## Help is context, not the answer to a query, so it goes to stderr and stdout
## stays clean for data (cli-output-spec §1).
proc printHelp() =
  stderr.writeLine "boilerplate-cli-ui-nim - Nim CLI with an embedded web UI"
  stderr.writeLine ""
  stderr.writeLine "Usage:"
  stderr.writeLine "  boilerplate-cli-ui-nim <command> [options]"
  stderr.writeLine ""
  stderr.writeLine "Commands:"
  stderr.writeLine "  serve [--host H] [--port N]   run the HTTP server in the foreground"
  stderr.writeLine "  daemon start [--port N]       start it in the background"
  stderr.writeLine "  daemon stop [--port N]        stop the background server"
  stderr.writeLine "  daemon status [--port N]      report background server status"
  stderr.writeLine "  guide [--human]               the embedded operator guide"
  stderr.writeLine "  help-json                     machine-readable command catalog"
  stderr.writeLine "  version [--json]              show version information"
  stderr.writeLine "  help                          show this help message"
  stderr.writeLine ""
  stderr.writeLine "Endpoints:"
  stderr.writeLine "  GET  /            Web UI"
  stderr.writeLine "  GET  /api/status  Server status (JSON)"
  stderr.writeLine "  GET  /_health     Liveness: {ok,service,pid}"
  stderr.writeLine "  POST /_shutdown   Stop the server (token-gated off-loopback)"
  stderr.writeLine ""
  stderr.writeLine "Exit codes: 0 ok, 80-89 input, 90-99 state, 100-109 external, 110-119 internal"

# ─── Flags ──────────────────────────────────────────────────────

proc hasFlag(args: seq[string], name: string): bool =
  for a in args:
    if a == name: return true
  false

## Reads --name value or --name=value.
proc flagValue(args: seq[string], name: string): string =
  let prefix = name & "="
  for i, a in args:
    if a == name and i + 1 < args.len: return args[i + 1]
    if a.startsWith(prefix): return a[prefix.len .. ^1]
  ""

## The host default MUST be loopback (cli-daemon-spec §1): serving the whole
## network is a deliberate act, never something that happens because nobody
## passed a flag.
proc resolveHost(args: seq[string]): string =
  result = flagValue(args, "--host")
  if result.len == 0: result = flagValue(args, "-host")
  if result.len == 0: result = getEnv("HOST")
  if result.len == 0: result = DefaultHost

proc resolvePort(args: seq[string]): int =
  var raw = flagValue(args, "--port")
  if raw.len == 0: raw = flagValue(args, "-port")
  if raw.len == 0: raw = flagValue(args, "-p")
  if raw.len == 0: raw = getEnv("PORT")
  if raw.len == 0: return DefaultPort
  try:
    result = parseInt(raw)
  except ValueError:
    die(ExitMissingArg, "bad_flag_value",
        "--port must be a number, got \"" & raw & "\"",
        "boilerplate-cli-ui-nim serve --port 8080")

# ─── Request handling ───────────────────────────────────────────

proc headers(contentType: string): HttpHeaders =
  newHttpHeaders([
    ("Content-Type", contentType),
    ("Cache-Control", "no-cache, no-store, must-revalidate")
  ])

proc isLoopback(host: string): bool =
  host in ["127.0.0.1", "localhost", "::1"]

## Off-loopback, an open shutdown route is a remote kill switch (§3).
proc shutdownAuthorized(req: Request): bool =
  if boundLoopback: return true
  let token = getEnv("SHUTDOWN_TOKEN")
  if token.len == 0: return false
  $req.headers.getOrDefault("X-Shutdown-Token") == token

proc handler(req: Request) {.async.} =
  let path = req.url.path

  # ─── Daemon lifecycle (cli-daemon-spec §2, §3) ────────────────
  if path == "/_health":
    # Open and cheap: liveness only, no dependency checks.
    let body = $(%*{
      "ok": true,
      "service": TOOL,
      "pid": getCurrentProcessId(),
      "port": boundPort
    })
    await req.respond(Http200, body, headers("application/json"))
    return

  if path == "/_shutdown":
    if req.reqMethod != HttpPost:
      await req.respond(Http405,
        """{"ok":false,"error":{"code":85,"type":"method_not_allowed","message":"POST /_shutdown","recoverable":false}}""",
        headers("application/json"))
      return
    if not shutdownAuthorized(req):
      # 403, and the process MUST NOT stop.
      await req.respond(Http403,
        """{"ok":false,"error":{"code":90,"type":"forbidden","message":"X-Shutdown-Token required when bound off-loopback","recoverable":false}}""",
        headers("application/json"))
      return
    # Answer before exiting, so the caller learns the request was accepted.
    await req.respond(Http200, """{"ok":true,"stopping":true}""",
                      headers("application/json"))
    removeFile(PidFile)
    quit(0)

  # ─── The guide over HTTP (cli-guide-spec §3) ──────────────────
  if path == "/guide":
    await req.respond(Http200, GUIDE_JSON, headers("application/json"))
    return
  if path == "/llms.txt":
    await req.respond(Http200, LLMS_TXT, headers("text/plain; charset=utf-8"))
    return

  case path
  of "/":
    await req.respond(Http200, INDEX_HTML, headers("text/html"))
  of "/js/app.js":
    await req.respond(Http200, APP_JS, headers("application/javascript"))
  of "/css/styles.css":
    await req.respond(Http200, STYLES_CSS, headers("text/css"))
  # Components
  of "/js/components/AppLayout.js":
    await req.respond(Http200, APPLAYOUT_JS, headers("application/javascript"))
  of "/js/components/Sidebar.js":
    await req.respond(Http200, SIDEBAR_JS, headers("application/javascript"))
  of "/js/components/StatusCard.js":
    await req.respond(Http200, STATUSCARD_JS, headers("application/javascript"))
  # Views
  of "/js/views/Dashboard.js":
    await req.respond(Http200, DASHBOARD_JS, headers("application/javascript"))
  of "/js/views/Settings.js":
    await req.respond(Http200, SETTINGS_JS, headers("application/javascript"))
  # API endpoints
  of "/api/status":
    let response = $(%*{
      "status": "running",
      "port": boundPort,
      "uptime": formatUptime(),
      "version": VERSION
    })
    await req.respond(Http200, response, headers("application/json"))
  of "/api/health":
    let response = $(%*{
      "ok": true,
      "service": TOOL,
      "pid": getCurrentProcessId(),
      "port": boundPort
    })
    await req.respond(Http200, response, headers("application/json"))
  else:
    await req.respond(Http404, "Not found")

## Runs the server in the foreground, bound to the requested address — not
## every interface, which is what an empty address means to asynchttpserver
## (cli-daemon-spec §1).
proc runServer(host: string, port: int) =
  boundLoopback = isLoopback(host)
  boundPort = port
  startTime = now()

  let server = newAsyncHttpServer()

  # Startup lines are context — stderr, never stdout (§1).
  stderr.writeLine TOOL & " serving on http://" & host & ":" & $port & "/"
  stderr.writeLine "  API: http://" & host & ":" & $port & "/api/status"

  try:
    waitFor server.serve(Port(port), handler, host)
  except OSError:
    die(ExitPrecondition, "port_unavailable",
        "cannot bind " & host & ":" & $port,
        "boilerplate-cli-ui-nim serve --port " & $(port + 1))

# ─── Daemon lifecycle (cli-daemon-spec §4) ──────────────────────
#
# /_health is the source of truth for liveness, not the pid file, which goes
# stale when a process dies without cleaning up. Every subcommand is idempotent.

proc probeHealth(port: int): bool =
  var client = newHttpClient(timeout = 1000)
  try:
    let resp = client.request("http://127.0.0.1:" & $port & "/_health", HttpGet)
    result = resp.status.startsWith("200")
  except CatchableError:
    result = false
  finally:
    client.close()

## Polls every 100ms for up to 5s, rather than sleeping a fixed amount (§4).
## Named waitForHealth, not waitFor: asyncdispatch already exports waitFor for
## futures, and shadowing it here would be a trap for the next reader.
proc waitForHealth(port: int, want: bool): bool =
  for _ in 0 ..< 50:
    if probeHealth(port) == want: return true
    sleep(100)
  false

proc readPid(): int =
  try:
    parseInt(readFile(PidFile).strip())
  except CatchableError:
    0

## Idempotent: an already-healthy port means report it and succeed, rather than
## racing a second process onto it (§4).
proc daemonStart(host: string, port: int) =
  if probeHealth(port):
    emit(%*{"ok": true, "running": true, "already_running": true, "port": port})
    return

  # The shell backgrounds the server and exits immediately, so the daemon is
  # orphaned to init rather than dying with the CLI that started it; setsid
  # gives it its own session.
  let exe = getAppFilename()
  let cmd = "nohup setsid \"" & exe & "\" serve --host " & host &
            " --port " & $port & " >> " & LogFile & " 2>&1 & echo $! > " & PidFile
  discard execShellCmd(cmd)

  if not waitForHealth(port, true):
    let pid = readPid()
    if pid > 0:
      discard execShellCmd("kill " & $pid & " 2>/dev/null")
    removeFile(PidFile)
    die(ExitExternal, "daemon_unhealthy",
        "started but /_health never answered on port " & $port & " (see " & LogFile & ")",
        "boilerplate-cli-ui-nim serve --port " & $port)

  emit(%*{
    "ok": true, "running": true, "already_running": false,
    "pid": readPid(), "port": port, "log": LogFile
  })

## A no-op success when nothing is running: an agent stopping an
## already-stopped daemon has got what it asked for (§4).
proc daemonStop(port: int) =
  if not probeHealth(port):
    removeFile(PidFile)
    emit(%*{"ok": true, "running": false, "stopped": false, "port": port})
    return

  var client = newHttpClient(timeout = 2000)
  let token = getEnv("SHUTDOWN_TOKEN")
  if token.len > 0:
    client.headers = newHttpHeaders([("X-Shutdown-Token", token)])

  var ok = false
  var status = ""
  try:
    let resp = client.request("http://127.0.0.1:" & $port & "/_shutdown", HttpPost)
    status = resp.status
    ok = status.startsWith("200")
  except CatchableError:
    client.close()
    die(ExitExternal, "shutdown_failed", "POST /_shutdown failed",
        "boilerplate-cli-ui-nim daemon status --port " & $port)
  client.close()

  if not ok:
    die(ExitExternal, "shutdown_refused", "POST /_shutdown returned " & status,
        "set SHUTDOWN_TOKEN if the daemon is bound off-loopback")

  discard waitForHealth(port, false)
  removeFile(PidFile)
  emit(%*{"ok": true, "running": false, "stopped": true, "port": port})

## Status only ever reads — it never carries the shutdown token (§4).
proc daemonStatus(port: int) =
  if not probeHealth(port):
    emit(%*{"ok": true, "running": false, "port": port})
    return
  emit(%*{
    "ok": true, "running": true, "pid": readPid(), "port": port, "log": LogFile
  })

# ─── Main ───────────────────────────────────────────────────────

proc main() =
  var args: seq[string] = @[]
  for i in 1 .. paramCount():
    args.add(paramStr(i))

  if args.len == 0:
    printHelp()
    quit(ExitMissingArg)

  let cmd = args[0]
  let rest = args[1 .. ^1]

  case cmd
  of "help", "--help", "-h":
    printHelp()
  of "version":
    if hasFlag(rest, "--json"):
      emit(%*{"version": VERSION, "name": TOOL})
    else:
      echo TOOL & " v" & VERSION
  of "guide":
    if hasFlag(rest, "--human"): echo GUIDE_MARKDOWN
    else: echo GUIDE_JSON
  of "help-json":
    echo HELP_JSON
  of "serve":
    runServer(resolveHost(rest), resolvePort(rest))
  of "daemon":
    if rest.len == 0:
      die(ExitMissingArg, "missing_argument",
          "daemon needs a subcommand: start, stop or status",
          "boilerplate-cli-ui-nim daemon status")
    let sub = rest[0]
    let tail = if rest.len > 1: rest[1 .. ^1] else: @[]
    let port = resolvePort(tail)
    case sub
    of "start": daemonStart(resolveHost(tail), port)
    of "stop": daemonStop(port)
    of "status": daemonStatus(port)
    else:
      die(ExitUnknownCommand, "unknown_command",
          "unknown daemon subcommand \"" & sub & "\"",
          "boilerplate-cli-ui-nim daemon status")
  # Back-compat aliases for the pre-spec command names.
  of "start":
    if hasFlag(rest, "-daemon") or hasFlag(rest, "--daemon"):
      daemonStart(resolveHost(rest), resolvePort(rest))
    else:
      runServer(resolveHost(rest), resolvePort(rest))
  of "stop":
    daemonStop(resolvePort(rest))
  of "status":
    daemonStatus(resolvePort(rest))
  else:
    die(ExitUnknownCommand, "unknown_command",
        "unknown command \"" & cmd & "\"",
        "boilerplate-cli-ui-nim help-json")

main()
