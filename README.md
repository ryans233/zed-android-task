# zed-android-task

给 [Zed](https://zed.dev) 用的 Android 常用任务脚本（bash）。同一份 `tasks.json` 配置可在任意 Android 项目中复用：脚本按当前目录自动探测 `applicationId`、flavor 与 build type，无需逐项目配置。

```
zed-android-task {install|run} [variant]
zed-android-task {pidcat|logcat|tlog} [package]
zed-android-task preview <file.kt> [options]
```

## 安装

```bash
git clone <this-repo> ~/Projects/GitHubProjects/zed-android-task
ln -s ~/Projects/GitHubProjects/zed-android-task/zed-android-task ~/.local/bin/zed-android-task
```

确保 `~/.local/bin` 在 `PATH` 中。依赖：

| 命令 | 依赖 |
| --- | --- |
| `install` / `run` | 项目根目录下的 `gradlew`、`adb` |
| `pidcat` | [`pidcat`](https://github.com/JakeWharton/pidcat) |
| `logcat` | `adb` |
| `tlog` | [`tlog`](https://github.com/ryans233/tlog) |
| `preview` | `android` CLI（[Android CLI](https://developer.android.com/tools/android-cli)）、`python3`、Pillow、Android Studio（Quail 1 或更新） |

所有命令都应在 Android 项目根目录执行（脚本读取 `app/build.gradle[.kts]`、调用 `./gradlew`）。

## 子命令

| 命令 | 行为 |
| --- | --- |
| `install [variant]` | `exec ./gradlew assemble<Variant> install<Variant>`，构建并以 `exec` 替换当前进程 |
| `run [variant]` | 构建安装后，用 `adb shell monkey -p <pkg> -c android.intent.category.LAUNCHER 1` 启动 launcher |
| `pidcat [package]` | `exec pidcat <pkg>` |
| `logcat [package]` | `adb logcat -v color --pid=$(adb shell pidof -s <pkg>) '*:V'` |
| `tlog [package]` | `exec tlog --filter package:<pkg>` |
| `preview <file.kt>` | 渲染文件中全部 `@Preview` 并拼成一张 PNG，用 Zed 打开 |

`variant` 默认为 `debug`；省略 `package` 时自动探测。

### variant 解析

variant 以 `debug` 或 `release` 结尾（大小写不敏感），其前缀即 flavor：

| 输入 | flavor | build type | Gradle 任务后缀 |
| --- | --- | --- | --- |
| `debug` | — | debug | `Debug` |
| `apiDevDebug` | `apiDev` | debug | `ApiDevDebug` |
| `productionRelease` | `production` | release | `ProductionRelease` |

无法拆出 `debug`/`release` 时直接报错。

### 包名探测

1. `app/build.gradle.kts` 或 `app/build.gradle` 中 `defaultConfig` 的 `applicationId`（单双引号均支持）；
2. 回退到 `app/src/main/AndroidManifest.xml` 的 `package="…"`（为旧项目保留）；
3. 叠加 variant 对应的 `applicationIdSuffix`：`productFlavors` 中的 flavor 块 + `buildTypes` 中的 build type 块，两者相加。

flavor/build type 块识别同时支持 Kotlin DSL（`create("name") { }`、`named("name") { }`）和 Groovy DSL（`name { }`），后缀可写在同一行或块内。探测失败时会提示显式传入包名，例如 `zed-android-task logcat com.example.app`。

### preview

```bash
zed-android-task preview app/src/main/java/.../HomeScreen.kt
```

流程：

1. 扫描 Kotlin 文件，找出带 `@Preview` 的 composable。支持全限定注解（`@androidx.compose.ui.tooling.preview.Preview`）、跨行注解参数、元注解（如 `@PreviewLightDark` 或自定义 `@XxxPreview`），并会剔除注释与字符串字面量中的误匹配；
2. 对每个函数调用 `android studio render-compose-preview <file> <name> --output-image-file <png>`；
3. 用 Pillow 把成功的渲染结果拼成网格图（带文件名标题和每个预览的名称标签），默认列数 `ceil(sqrt(n))`；
4. 用 `zed` 打开拼图（未安装 `zed` 时打印路径）。

选项：

| 选项 | 说明 |
| --- | --- |
| `--project <name\|path>` | 指定要查询的 Android Studio 项目；仅在同时打开多个项目时需要 |
| `--out <path>` | 输出路径，默认 `~/.cache/zed-android-task/<file>-previews.png` |
| `--columns <n>` | 网格列数 |
| `--no-open` | 只生成图片，不打开 |
| `-h`, `--help` | 帮助 |

前置条件：Android Studio 已打开对应项目（`render-compose-preview` 依赖 IDE 内部渲染），且 `android` CLI 在 `PATH`。

## 缓存与临时文件

| 路径 | 用途 |
| --- | --- |
| `~/.cache/zed-android-task/venv` | 系统 Python 缺少 Pillow 时自动创建的 venv |
| `~/.cache/zed-android-task/*-previews.png` | `preview` 默认输出 |
| `$TMPDIR/zed-compose-preview.*` | 单次渲染的中间图片/日志，结束后删除 |

`XDG_CACHE_HOME` 遵循标准：设置后会替代 `~/.cache`。

## Zed tasks.json 示例

放在项目 `.zed/tasks.json`。Zed 默认在 worktree 根目录执行任务，无需写 `cwd`。以三 flavor（qa/uat/prod）项目为例：

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

要点：

- `run <variant>` 一次性完成构建、安装、启动，适合与 `hide: "on_success"` 配合；
- `pidcat`/`logcat`/`tlog` 传显式包名可省略探测开销，且在自动探测失败时仍可用；
- 日志类任务用 `use_new_terminal: true`，避免占用构建终端；
- `install`/`run`/`pidcat`/`logcat`/`tlog` 内部用 `exec` 替换进程；`install` 之后不会执行同一任务的后续命令，需要“装完即跑”请用 `run`。
