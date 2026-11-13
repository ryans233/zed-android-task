# zed-android-task — Android tasks for Zed

Reusable Android task script (bash) for [Zed](https://zed.dev).

[English](README.md) | [中文](README_ZH.md)

One `tasks.json` works across any Android project: the script auto-detects `applicationId`, flavor and build type from the current directory — no per-project configuration.

```
zed-android-task {install|run} [variant]
zed-android-task {pidcat|logcat|tlog} [package]
zed-android-task preview <file.kt> [options]
```

## Installation

```bash
git clone <this-repo> ~/Projects/GitHubProjects/zed-android-task
ln -s ~/Projects/GitHubProjects/zed-android-task/zed-android-task ~/.local/bin/zed-android-task
```

Make sure `~/.local/bin` is on `PATH`. Dependencies:

| Command | Requires |
| --- | --- |
| `install` / `run` | project-root `gradlew`, `adb` |
| `pidcat` | [`pidcat`](https://github.com/JakeWharton/pidcat) |
| `logcat` | `adb` |
| `tlog` | [`tlog`](https://github.com/ryans233/tlog) |
| `preview` | `android` CLI ([Android CLI](https://developer.android.com/tools/android-cli)), `python3`, Pillow, Android Studio (Quail 1 or newer) |

Run every command from the Android project root: the script reads `app/build.gradle[.kts]` and invokes `./gradlew`.

## Commands

| Command | Behavior |
| --- | --- |
| `install [variant]` | `exec ./gradlew assemble<Variant> install<Variant>` — build and replace the process via `exec` |
| `run [variant]` | Build + install, then launch the launcher with `adb shell monkey -p <pkg> -c android.intent.category.LAUNCHER 1` |
| `pidcat [package]` | `exec pidcat <pkg>` |
| `logcat [package]` | `adb logcat -v color --pid=$(adb shell pidof -s <pkg>) '*:V'` |
| `tlog [package]` | `exec tlog --filter package:<pkg>` |
| `preview <file.kt>` | Render every `@Preview`, tile them into one PNG, open it in Zed |

`variant` defaults to `debug`; omitting `package` triggers auto-detection.

### Variant parsing

A variant ends with `debug` or `release` (case-insensitive); the prefix is the flavor:

| Input | Flavor | Build type | Gradle task suffix |
| --- | --- | --- | --- |
| `debug` | — | debug | `Debug` |
| `apiDevDebug` | `apiDev` | debug | `ApiDevDebug` |
| `productionRelease` | `production` | release | `ProductionRelease` |

If neither `debug` nor `release` can be split off the tail, the script errors out.

### Package detection

1. `applicationId` in `defaultConfig` of `app/build.gradle.kts` or `app/build.gradle` (double or single quotes);
2. fallback to `package="…"` in `app/src/main/AndroidManifest.xml` (legacy projects);
3. append the variant's `applicationIdSuffix`: from the matching flavor block under `productFlavors` plus the matching build type block under `buildTypes`.

Flavor/build-type blocks are recognized in both Kotlin DSL (`create("name") { }`, `named("name") { }`) and Groovy DSL (`name { }`); suffixes may sit on the block's opening line or inside it. When detection fails, the error tells you to pass the package explicitly, e.g. `zed-android-task logcat com.example.app`.

### preview

```bash
zed-android-task preview app/src/main/java/.../HomeScreen.kt
```

How it works:

1. Scan the Kotlin file for composables annotated with `@Preview`. Fully-qualified annotations (`@androidx.compose.ui.tooling.preview.Preview`), multi-line annotation arguments and meta-annotations (`@PreviewLightDark` or custom `@XxxPreview`) are supported; matches inside comments and string literals are stripped;
2. For each function, call `android studio render-compose-preview <file> <name> --output-image-file <png>`;
3. Tile successful renders into a grid with Pillow (file title plus a label per preview); default column count is `ceil(sqrt(n))`;
4. Open the tiled image in Zed (or print its path when `zed` is unavailable).

Options:

| Option | Description |
| --- | --- |
| `--project <name\|path>` | Android Studio project to query; only needed with multiple projects open |
| `--out <path>` | Output path, default `~/.cache/zed-android-task/<file>-previews.png` |
| `--columns <n>` | Grid columns |
| `--no-open` | Generate the image without opening it |
| `-h`, `--help` | Help |

Prerequisites: Android Studio with the project open (`render-compose-preview` renders inside the IDE) and the `android` CLI on `PATH`.

## Cache and temporary files

| Path | Purpose |
| --- | --- |
| `~/.cache/zed-android-task/venv` | Virtualenv created automatically when the system Python lacks Pillow |
| `~/.cache/zed-android-task/*-previews.png` | Default `preview` output |
| `$TMPDIR/zed-compose-preview.*` | Per-run intermediate images/logs, removed afterwards |

`XDG_CACHE_HOME` is honored: when set, it replaces `~/.cache`.

## Zed tasks.json example

Place it in the project's `.zed/tasks.json`. Zed runs tasks in the worktree root by default, so `cwd` is unnecessary. Example for a three-flavor (qa/uat/prod) project:

```json
[
  {
    "label": "Android: Install and Run qaDebug",
    "command": "zed-android-task run qaDebug",
    "allow_concurrent_runs": false,
    "use_new_terminal": false,
    "hide": "on_success",
  },
  {
    "label": "Android: pidcat qaDebug",
    "command": "zed-android-task pidcat com.example.app.test",
    "use_new_terminal": true,
  },
  {
    "label": "Android: Install and Run uatDebug",
    "command": "zed-android-task run uatDebug",
    "allow_concurrent_runs": false,
    "use_new_terminal": false,
    "hide": "on_success",
  },
  {
    "label": "Android: pidcat uatDebug",
    "command": "zed-android-task pidcat com.example.app.uat",
    "use_new_terminal": true,
  },
  {
    "label": "Android: Install and Run prodDebug",
    "command": "zed-android-task run prodDebug",
    "allow_concurrent_runs": false,
    "use_new_terminal": false,
    "hide": "on_success",
  },
  {
    "label": "Android: pidcat prodDebug",
    "command": "zed-android-task pidcat com.example.app",
    "use_new_terminal": true,
  },
  {
    "label": "Android: preview current file",
    "command": "zed-android-task preview \"$ZED_FILE\"",
    "allow_concurrent_runs": true,
    "use_new_terminal": true,
  },
]
```

Notes:

- `run <variant>` builds, installs and launches in one go — pair it with `hide: "on_success"`;
- passing an explicit package to `pidcat`/`logcat`/`tlog` skips detection and keeps working when auto-detection cannot resolve a package;
- log tasks should use `use_new_terminal: true` so they do not occupy the build terminal;
- `install`/`run`/`pidcat`/`logcat`/`tlog` replace their process via `exec`; nothing after `install` in the same task will run — use `run` when you want install-then-launch.
