# boilerplate-cli-ui-nim

Nim CLI with embedded web UI. Single binary, no runtime dependencies.

Part of [SuperCLI](https://github.com/javimosch/supercli) - build CLI/UI plugins fast for 2026.

| Stack | Repo | Binary |
|-------|------|--------|
| Go + inline HTML | [boilerplate-cli-ui-go](https://github.com/javimosch/boilerplate-cli-ui-go) | ~5MB |
| Go + Vue 3 CDN | [boilerplate-cli-ui-go-v2-vue](https://github.com/javimosch/boilerplate-cli-ui-go-v2-vue) | ~5MB |
| Go + React 18 CDN | [boilerplate-cli-ui-go-v2-react](https://github.com/javimosch/boilerplate-cli-ui-go-v2-react) | ~5MB |
| Deno + vanilla JS | [boilerplate-cli-ui-deno](https://github.com/javimosch/boilerplate-cli-ui-deno) | ~76MB |
| Node.js + vanilla JS | [boilerplate-cli-ui-node](https://github.com/javimosch/boilerplate-cli-ui-node) | ~123MB |
| Python + React CDN | [boilerplate-cli-ui-python](https://github.com/javimosch/boilerplate-cli-ui-python) | ~10MB |
| Rust + vanilla JS | [boilerplate-cli-ui-rust](https://github.com/javimosch/boilerplate-cli-ui-rust) | ~1.1MB |
| .NET 8 + Vue 3 | [boilerplate-cli-ui-dotnet](https://github.com/javimosch/boilerplate-cli-ui-dotnet) | ~89MB |
| C++ + Vue 3 | [boilerplate-cli-ui-cpp](https://github.com/javimosch/boilerplate-cli-ui-cpp) | ~493KB |
| **Nim + Vue 3** | **boilerplate-cli-ui-nim** | **~364KB** |
| Zig + Vue 3 | [boilerplate-cli-ui-zig](https://github.com/javimosch/boilerplate-cli-ui-zig) | ~190KB |
| Dart + Vue 3 | [boilerplate-cli-ui-dart](https://github.com/javimosch/boilerplate-cli-ui-dart) | ~6.4MB |
|| V + Vue 3 | [boilerplate-cli-ui-v](https://github.com/javimosch/boilerplate-cli-ui-v) | ~1.2MB |
|| Crystal + Vue 3 | [boilerplate-cli-ui-crystal](https://github.com/javimosch/boilerplate-cli-ui-crystal) | ~3.1MB |

## Architecture

```
boilerplate-cli-ui-nim/
├── src/
│   ├── server.nim        # CLI + HTTP server
│   └── ui/               # Frontend (embedded at compile time via staticRead)
│       ├── index.html
│       ├── js/
│       │   ├── app.js
│       │   ├── components/
│       │   └── views/
│       └── css/
│           └── styles.css
├── boilerplate-cli-ui-nim.nimble
├── build.sh
└── README.md
```

## Key Feature: staticRead

Frontend files are **embedded into the binary** at compile time:

```nim
const INDEX_HTML = staticRead("ui/index.html")
const APP_JS = staticRead("ui/js/app.js")
```

`staticRead` resolves paths relative to the `.nim` source file's directory.
Since `server.nim` is in `src/`, `staticRead("ui/index.html")` reads `src/ui/index.html`.

**Benefits:**
- Single binary output (no runtime file dependencies)
- Compile-time embedding
- Python-like syntax (fast to write)

## Prerequisites

```bash
# Install Nim
curl https://nim-lang.org/choosenim/init.sh -sSf | bash -s -- -y
export PATH=$HOME/.nimble/bin:$PATH
```

## Build

```bash
chmod +x build.sh
./build.sh
```

Or manually:

```bash
nim c -d:release --opt:size src/server.nim
```

## Usage

```bash
# Start server (foreground)
./boilerplate-cli-ui-nim start

# Start on custom port
./boilerplate-cli-ui-nim start -p 3000

# Show version
./boilerplate-cli-ui-nim version

# Show help
./boilerplate-cli-ui-nim help
```

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /` | Web UI |
| `GET /api/status` | Server status (JSON) |
| `GET /api/health` | Health check (JSON) |

## Hashbang Routing

Routes use hashbang URLs:
- `http://localhost:8080/#/dashboard` - Dashboard view
- `http://localhost:8080/#/settings` - Settings view
- `http://localhost:8080/` - Defaults to dashboard

## Frontend Stack

- **Vue 3** (CDN) - Reactive UI with hashbang routing
- **Tailwind CSS** (CDN) - Utility-first styling
- **Lucide Icons** (CDN) - Icon library

## Comparison

| Aspect | Go | Rust | C++ | Nim | Zig |
|--------|-----|------|-----|-----|-----|
| Binary size | ~5MB | ~1.1MB | ~493KB | ~364KB | ~190KB |
| Dev speed | ⭐⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐ |
| Syntax | Go | Rust | C++ | Python-like | C-like |
| Ecosystem | Large | Medium | Large | Medium | Small |
