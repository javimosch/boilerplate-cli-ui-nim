# boilerplate-cli-ui-nim

Nim CLI with embedded web UI. Single binary, no runtime dependencies.
Part of [SuperCLI](https://github.com/javimosch/supercli) - build CLI/UI plugins fast for 2026.
<!-- FLEET-TABLE:BEGIN -->

| Stack | Binary | Cold start | Idle RSS | Specs | SDK |
|-------|--------|-----------:|---------:|:-----:|----:|
| [machin + React 18 CDN](https://github.com/javimosch/boilerplate-cli-ui-machin) | 63 KB | 2 ms | 3.1 MB | 28/28 | ~2 MB |
| [machin isomorphic (wasm UI)](https://github.com/javimosch/boilerplate-cli-ui-machin-isomorphic) | 76 KB | 2 ms | 3.1 MB | 28/28 | ~2 MB |
| **Nim + Vue 3** | **372 KB** | **1 ms** | **2.0 MB** | **2/21** | **~50 MB** |
| [C++ + Vue 3](https://github.com/javimosch/boilerplate-cli-ui-cpp) | 692 KB | 4 ms | 7.4 MB | 28/28 | ~2000 MB |
| [Zig + Vue 3](https://github.com/javimosch/boilerplate-cli-ui-zig) | 971 KB | 1 ms | 2.0 MB | 28/28 | ~50 MB |
| [Rust + vanilla JS](https://github.com/javimosch/boilerplate-cli-ui-rust) | 1003 KB | 1 ms | 2.5 MB | 28/28 | ~800 MB |
| [V + Vue 3](https://github.com/javimosch/boilerplate-cli-ui-v) | 1.2 MB | 2 ms | 2.5 MB | 5/20 | ~5 MB |
| [Crystal + Vue 3](https://github.com/javimosch/boilerplate-cli-ui-crystal) | 3.1 MB | 3 ms | 5.9 MB | 5/20 | ~50 MB |
| [Go + Vue 3 CDN](https://github.com/javimosch/boilerplate-cli-ui-go-v2-vue) | 5.5 MB | 3 ms | 5.8 MB | 28/28 | ~150 MB |
| [Go + React 18 CDN](https://github.com/javimosch/boilerplate-cli-ui-go-v2-react) | 5.5 MB | 4 ms | 5.6 MB | 28/28 | ~150 MB |
| [Dart + Vue 3](https://github.com/javimosch/boilerplate-cli-ui-dart) | 6.3 MB | 6 ms | 7.2 MB | 2/21 | ~400 MB |
| [Deno + vanilla JS](https://github.com/javimosch/boilerplate-cli-ui-deno) | 76.1 MB | 25 ms | 45.0 MB | 28/28 | ~100 MB |
| [Node.js + vanilla JS](https://github.com/javimosch/boilerplate-cli-ui-node) | 122.8 MB | 62 ms | 53.3 MB | 28/28 | ~500 MB |

Not measured in this run (toolchain unavailable): [Python + React CDN](https://github.com/javimosch/boilerplate-cli-ui-python), [.NET 8 + Vue 3](https://github.com/javimosch/boilerplate-cli-ui-dotnet).

*Binary size, cold start (median of 11 `version` runs) and idle RSS measured on Linux-x86_64 on 2026-09-08. **Specs** is the [cli-spec-conformance](https://github.com/javimosch/cli-spec-conformance) score across cli-output-spec, cli-guide-spec and cli-daemon-spec, measured by running each binary — not claimed. Every row builds the same reference app; a row at 28/28 also implements the same agent-first contract, which is what makes its size comparable to the others. Rows below 28/28 have not been converted yet, so read their sizes as a floor. Regenerate with [boilerplate-cli-ui-fleet](https://github.com/javimosch/boilerplate-cli-ui-fleet); never edit this table by hand.*

<!-- FLEET-TABLE:END -->
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
## Key Feature: staticRead
Frontend files are **embedded into the binary** at compile time:
```nim
const INDEX_HTML = staticRead("ui/index.html")
const APP_JS = staticRead("ui/js/app.js")
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
## Build
chmod +x build.sh
./build.sh
Or manually:
nim c -d:release --opt:size src/server.nim
## Usage
# Start server (foreground)
./boilerplate-cli-ui-nim start
# Start on custom port
./boilerplate-cli-ui-nim start -p 3000
# Show version
./boilerplate-cli-ui-nim version
# Show help
./boilerplate-cli-ui-nim help
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
| Binary size | ~5MB | ~150MB | ~1.1MB | ~800MB | ~493KB | ~2GB+ | ~364KB | ~50MB | ~190KB | ~50MB |
| Dev speed | ⭐⭐⭐ | ⭐⭐ | ⭐ | ⭐⭐⭐ | ⭐⭐ |
| Syntax | Go | Rust | C++ | Python-like | C-like |
| Ecosystem | Large | Medium | Large | Medium | Small |
