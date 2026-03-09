# Campaign Tool

A D&D session management tool for running homebrew campaigns. A Phoenix/LiveView server indexes your campaign Markdown files and provides a browser UI for planning and running sessions. An Android WebView shell acts as the DM tablet, and a Chromecast receiver displays the battlemap with fog of war on a projector.

## Architecture

```
campaign-tool/
├── server/          ← Elixir/Phoenix app (LiveView UI, SQLite index, session GenServer)
└── android/         ← Kotlin WebView shell with Cast SDK
```

Your campaign data lives in a **separate directory** (e.g. `~/campaign`), watched for changes by the server, which keeps a SQLite index in sync.

## Campaign Data Layout

```
~/campaign/
├── .campaign.yml          ← global metadata (name, system, dm)
├── npcs/
├── locations/
├── factions/
├── sessions/
├── stat-blocks/
├── maps/
│   └── assets/            ← Wonderdraft PNG exports
└── audio/
    ├── music/             ← ambient MP3s
    └── sfx/{section}/     ← soundboard MP3s grouped by section
```

Each entity is a Markdown file with YAML frontmatter. The `id` is the filename slug (e.g. `elara-moonwhisper.md` → `id: elara-moonwhisper`). The `type` field must match the directory name.

## Running the Server

Requires Elixir 1.18+ / OTP 27+.

```bash
cd server
mix deps.get
mix ecto.setup
mix phx.server
```

The UI is available at `http://localhost:4000`.

By default the server watches `~/campaign` for your campaign files. Override with the `CAMPAIGN_DIR` environment variable:

```bash
CAMPAIGN_DIR=/path/to/your/campaign mix phx.server
```

**Git auto-sync:** If you set `SSH_KEY_PATH` to an SSH key that has push access to your campaign repo, the server will auto-commit and push changes after a 5-second debounce:

```bash
SSH_KEY_PATH=~/.ssh/id_ed25519 CAMPAIGN_DIR=~/campaign mix phx.server
```

## Android App

Open `android/` in Android Studio. Before building:

1. Set `sdk.dir` in `android/local.properties`
2. Register your receiver URL at [cast.google.com/publish](https://cast.google.com/publish) to get a Cast App ID
3. Set `CAST_APP_ID=<your-id>` in `android/local.properties`

Then build and install:

```bash
cd android
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

The app loads the server at `http://192.168.1.100:4000` by default — edit `MainActivity.kt` to match your server's IP. The Cast button in the toolbar launches the Chromecast receiver.

## Session Flow

1. **Plan** — Go to a session in the browser, open the session planner, create scenes, link NPCs/locations/stat blocks.
2. **Go Live** — Click "Go Live" to start the session GenServer and enter the session runner.
3. **Session runner tabs:**
   - **Plan** — Read scene notes, append session notes (auto-saved to the Markdown file).
   - **Map** — Select a map, paint fog of war with a brush. Changes are pushed live to the Chromecast.
   - **Combat** — Track initiative order and HP.
   - **Audio** — Play ambient music and SFX soundboard on the Chromecast.
4. **Chromecast** — The receiver at `/receiver?session_id=<id>` connects directly to the Phoenix Channel and displays the battlemap with fog overlay and plays audio.
