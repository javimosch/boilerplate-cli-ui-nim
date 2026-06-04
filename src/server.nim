import std/[asynchttpserver, asyncdispatch, json, strutils, times]
import std/parseopt

const VERSION = "1.0.0"

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

# Start time for uptime calculation
var startTime = now()

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

proc printHelp() =
  echo "boilerplate-cli-ui-nim - Nim CLI with embedded web UI"
  echo ""
  echo "Usage:"
  echo "  boilerplate-cli-ui-nim <command> [options]"
  echo ""
  echo "Commands:"
  echo "  start       Start HTTP server with web UI"
  echo "  version     Show version information"
  echo "  help        Show this help message"
  echo ""
  echo "Start Options:"
  echo "  -p, --port PORT  Port for HTTP server (default 8080)"
  echo ""
  echo "API Endpoints:"
  echo "  GET /            Web UI"
  echo "  GET /api/status  Server status (JSON)"
  echo "  GET /api/health  Health check (JSON)"

proc handler(req: Request) {.async.} =
  let path = req.url.path
  
  # Static UI files
  case path
  of "/":
    await req.respond(Http200, INDEX_HTML, newHttpHeaders([("Content-Type", "text/html")]))
  of "/js/app.js":
    await req.respond(Http200, APP_JS, newHttpHeaders([("Content-Type", "application/javascript")]))
  of "/css/styles.css":
    await req.respond(Http200, STYLES_CSS, newHttpHeaders([("Content-Type", "text/css")]))
  # Components
  of "/js/components/AppLayout.js":
    await req.respond(Http200, APPLAYOUT_JS, newHttpHeaders([("Content-Type", "application/javascript")]))
  of "/js/components/Sidebar.js":
    await req.respond(Http200, SIDEBAR_JS, newHttpHeaders([("Content-Type", "application/javascript")]))
  of "/js/components/StatusCard.js":
    await req.respond(Http200, STATUSCARD_JS, newHttpHeaders([("Content-Type", "application/javascript")]))
  # Views
  of "/js/views/Dashboard.js":
    await req.respond(Http200, DASHBOARD_JS, newHttpHeaders([("Content-Type", "application/javascript")]))
  of "/js/views/Settings.js":
    await req.respond(Http200, SETTINGS_JS, newHttpHeaders([("Content-Type", "application/javascript")]))
  # API endpoints
  of "/api/status":
    let uptime = formatUptime()
    let port = 8080  # TODO: make dynamic
    let response = $(%*{
      "status": "running",
      "port": port,
      "uptime": uptime,
      "version": VERSION,
      "start_time": $startTime
    })
    await req.respond(Http200, response, newHttpHeaders([("Content-Type", "application/json")]))
  of "/api/health":
    let response = $(%*{
      "status": "healthy",
      "version": VERSION
    })
    await req.respond(Http200, response, newHttpHeaders([("Content-Type", "application/json")]))
  else:
    await req.respond(Http404, "Not found")

proc main() =
  var port = 8080
  
  # Parse command line arguments
  for kind, key, val in getopt():
    case kind
    of cmdArgument:
      case key
      of "start":
        discard
      of "version":
        echo "boilerplate-cli-ui-nim v" & VERSION
        return
      of "help":
        printHelp()
        return
    of cmdLongOption, cmdShortOption:
      case key
      of "port", "p":
        port = parseInt(val)
    of cmdEnd:
      discard
  
  # Start server
  let server = newAsyncHttpServer()
  
  echo "Server starting on http://localhost:" & $port
  echo "UI available at http://localhost:" & $port & "/"
  echo "API available at http://localhost:" & $port & "/api/status"
  echo "Press Ctrl+C to stop"
  
  waitFor server.serve(Port(port), handler)

main()
