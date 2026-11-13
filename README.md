# StatusBar Plugin Template

Template for building [StatusBar](https://github.com/hytfjwr/StatusBar) plugins.

## Quick Start

1. Click **"Use this template"** on GitHub to create your plugin repository
2. Clone your new repo
3. Customize the plugin (see below)
4. `make dev` to build and install locally for testing

## Customization

1. **Makefile** — Update these variables at the top:
   - `PLUGIN_NAME` — Your Swift module name (e.g. `WeatherPlugin`)
   - `PLUGIN_ID` — Reverse-domain identifier (e.g. `com.example.weather`)
   - `VERSION` — Semver version string

2. **Package.swift** — Rename the product, target, and module to match `PLUGIN_NAME`

3. **Sources/** — Rename the `MyPlugin` directory to match your module name, then update the source files

4. **Plugin struct** — Update `PluginManifest` id/name and add your widgets

## Make Targets

| Target | Description |
|--------|-------------|
| `make build` | Release build via SPM |
| `make bundle` | Build + create `.statusplugin` bundle |
| `make package` | Bundle + create `.statusplugin.zip` |
| `make dev` | Bundle + install to `~/.config/statusbar/plugins/` |
| `make clean` | Remove build artifacts |

## Development Workflow

```bash
# Edit code, then:
make dev
# Plugin is installed locally — restart StatusBar or use Dev Mode to load
```

## Releasing

Releases are fully automated via GitHub Actions:

1. Go to **Actions → Release** in your GitHub repository
2. Click **"Run workflow"** and select a bump type (`patch` / `minor` / `major`)
3. The workflow automatically calculates the next version, builds, packages, creates a git tag, and publishes a GitHub Release

## Requirements

- macOS 26+
- Swift 6.2 / Xcode 26 beta
- [StatusBarKit](https://github.com/hytfjwr/StatusBarKit) 1.0.0+
