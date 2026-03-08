# Campaign Tool — Phase 1 Plan

## Context

Building a homebrew D&D 5.5E campaign management tool. The user writes notes in Markdown via Vim, designs maps in Wonderdraft, and needs a World Anvil-style browser UI for planning. Sessions are run from an Android tablet with a Chromecast projector for battlemap display.

**Phase 1 scope**: Elixir/Phoenix server with LiveView web UI, file watcher → SQLite index, entity browser/editor, map viewer, git auto-sync. Docker Compose for local deployment.

Future phases: map pins (2), session planner (3), Android app (4), Chromecast receiver (5).

---

## Project Structure

```
campaign-tool/
├── server/               ← Elixir/Phoenix app
├── android/              ← Phase 4 placeholder (.gitkeep)
├── receiver/             ← Phase 5 placeholder (.gitkeep)
├── docker-compose.yml
├── docker-compose.override.yml   ← local dev (gitignored)
├── .env                  ← host paths + SECRET_KEY_BASE (gitignored)
└── PLAN.md
```

Campaign data lives in a **separate git repo** (e.g. `~/campaign`), bind-mounted into the container at `/data/campaign`. The server never touches it directly except via Vim on the host or the web editor.

---

## Campaign Data Schema

All entities: Markdown file with YAML frontmatter. `type` field must match directory name. `id` is the filename slug (e.g. `elara-moonwhisper.md` → `id: elara-moonwhisper`).

### Directory layout (`~/campaign/`)
```
.campaign.yml         ← global metadata (name, system, dm)
npcs/
locations/
factions/
sessions/
stat-blocks/
maps/
  assets/             ← Wonderdraft PNG exports
```

### Frontmatter per type

**npc** — required: `name`, `status` (alive|deceased|unknown|missing), `role`
Optional: `race`, `class`, `level`, `location_id`, `faction_ids[]`, `portrait`, `stat_block_id`, `tags[]`

**location** — required: `name`, `location_type` (city|dungeon|wilderness|building|region|landmark|other)
Optional: `region`, `parent_location_id`, `map_id`, `faction_ids[]`, `tags[]`

**faction** — required: `name`, `status` (active|disbanded|secret|defunct)
Optional: `alignment`, `headquarters_id`, `leader_id`, `member_ids[]`, `tags[]`

**session** — required: `title`, `session_number`, `status` (planned|completed|cancelled)
Optional: `scheduled_date`, `actual_date`, `duration_hours`, `location_ids[]`, `npc_ids[]`, `map_ids[]`, `stat_block_ids[]`, `faction_ids[]`, `xp_awarded`, `loot_summary`, `tags[]`

**stat-block** — required: `name`, `cr`, `size`, `creature_type`, `source` (homebrew|book name)
Optional (required if homebrew): `hp`, `hp_formula`, `ac`, `ac_source`, `speed{}`, `ability_scores{}`, `saving_throws{}`, `skills{}`, `damage_immunities[]`, `senses`, `languages`, `challenge`, `proficiency_bonus`, `tags[]`

**map** — required: `name`, `map_type` (regional|city|district|dungeon|battlemap|world), `asset_path`
Optional: `width_px`, `height_px`, `scale`, `location_id`, `tags[]`, `pins[]` (Phase 2, empty for now)

### Example NPC file

```markdown
---
type: npc
id: elara-moonwhisper
name: Elara Moonwhisper
status: alive
role: quest-giver
race: Half-Elf
class: Wizard
level: 7
location_id: ironveil-city
faction_ids:
  - crimson-accord
tags:
  - mage
  - council-member
stat_block_id: elara-stat-block
---

Elara has served the Ironveil Mage Council for thirty years...
```

---

## Server Architecture

### `server/mix.exs` dependencies
```elixir
{:phoenix, "~> 1.7"},
{:phoenix_live_view, "~> 1.0"},
{:ecto_sqlite3, "~> 0.17"},
{:earmark, "~> 1.4"},
{:yaml_elixir, "~> 2.9"},
{:file_system, "~> 1.0"},
{:jason, "~> 1.4"},
{:bandit, "~> 1.0"}
```

### OTP Supervision Tree
```
CampaignTool.Application (one_for_one)
├── CampaignTool.Repo                        ← SQLite via Ecto
├── Phoenix.PubSub (name: CampaignTool.PubSub)
├── CampaignToolWeb.Endpoint
└── CampaignTool.Sync.Supervisor (rest_for_one)
    ├── CampaignTool.Sync.FileWatcher        ← :file_system subscription
    ├── CampaignTool.Sync.IndexWorker        ← debounce + parse + upsert
    └── CampaignTool.Sync.GitWorker          ← debounce + commit + push
```

`rest_for_one` on Sync.Supervisor: FileWatcher crash restarts the whole sync chain.

### Key files

| Path | Purpose |
|---|---|
| `lib/campaign_tool/application.ex` | Supervision tree |
| `lib/campaign_tool/repo.ex` | `Ecto.Repo`, adapter: `Ecto.Adapters.SQLite3` |
| `lib/campaign_tool/entities/entities.ex` | Context: `list_entities/2`, `get_entity!/2`, `upsert_entity/2`, `delete_entity/2`, `search/1` |
| `lib/campaign_tool/entities/schemas/{npc,location,faction,session,stat_block,map}.ex` | 6 Ecto schemas, string PKs (slugs) |
| `lib/campaign_tool/entities/types/string_list.ex` | Custom Ecto type: JSON-serialized `[]string` for SQLite |
| `lib/campaign_tool/sync/parser.ex` | Split frontmatter, parse YAML, validate type vs dir, render Markdown |
| `lib/campaign_tool/sync/file_watcher.ex` | Subscribe to inotify events; forward `.md` changes to IndexWorker + GitWorker |
| `lib/campaign_tool/sync/index_worker.ex` | Per-file debounce map (300ms); Parser → `upsert_entity` → FTS update → PubSub broadcast |
| `lib/campaign_tool/sync/git_worker.ex` | Batch debounce (5s); shells out: `git add -A`, `git commit`, `git push` with `GIT_SSH_COMMAND` |
| `lib/campaign_tool_web/router.ex` | LiveView routes |
| `lib/campaign_tool_web/live/dashboard_live.ex` | Entity counts, recently updated, upcoming sessions |
| `lib/campaign_tool_web/live/entity_browser_live.ex` | Filterable/searchable list per type; params: `?tag=`, `?status=`, `?q=` |
| `lib/campaign_tool_web/live/entity_detail_live.ex` | Rendered Markdown body + frontmatter sidebar + related entity links |
| `lib/campaign_tool_web/live/entity_editor_live.ex` | Raw textarea; writes file to disk; re-index confirmation via PubSub |
| `lib/campaign_tool_web/live/map_viewer_live.ex` | PNG served via Plug.Static from `/data/campaign/maps/assets/` |
| `priv/repo/migrations/` | 7 migrations: 6 entity tables + 1 FTS5 virtual table |
| `config/runtime.exs` | Reads: `CAMPAIGN_DIR`, `DATABASE_PATH`, `SSH_KEY_PATH`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT` |

### SQLite / Ecto notes
- All array fields (`faction_ids`, `tags`, etc.) use `StringList` custom type → stored as JSON text
- FTS5 virtual table `entities_fts(entity_type, entity_id, name, tags, body_raw)` with `tokenize='porter unicode61'`; contentless, populated by IndexWorker after each upsert
- Upserts: `Repo.insert(changeset, on_conflict: {:replace_all_except, [:inserted_at]}, conflict_target: :id)`

### Parser design (critical path)
```elixir
def parse_file(path) do
  with {:ok, content}    <- File.read(path),
       {:ok, fm, body}   <- split_frontmatter(content),   # split on "---\n"
       {:ok, data}       <- YamlElixir.read_from_string(fm),
       {:ok, type}       <- validate_type(data, path),    # type must match dir name
       {:ok, html}       <- Earmark.as_html(body) do
    {:ok, type, Map.merge(data, %{"body_raw" => body, "body_html" => html, "file_path" => path})}
  end
end
```

Type → directory mapping: `npc→npcs`, `location→locations`, `faction→factions`, `session→sessions`, `stat-block→stat-blocks`, `map→maps`

### IndexWorker debounce (important — Vim writes swap files)
```elixir
# State: %{timers: %{path => timer_ref}}
# Per-file timer cancellation prevents double-indexing on Vim's swap file writes
def handle_cast({:schedule, path, events}, %{timers: timers} = state) do
  if ref = timers[path], do: Process.cancel_timer(ref)
  ref = Process.send_after(self(), {:index, path, events}, 300)
  {:noreply, %{state | timers: Map.put(timers, path, ref)}}
end
```

### GitWorker SSH setup
`GIT_SSH_COMMAND` env var set to `"ssh -i /run/ssh/id_ed25519 -o StrictHostKeyChecking=no -o BatchMode=yes"`.
The container has `git` and `openssh-client` installed. SSH key mounted read-only from host at `/run/ssh/`.

### Entity editor write flow
Editor writes file → FileWatcher detects change → IndexWorker debounces → parses → upserts DB →
broadcasts `{:updated, id}` on PubSub topic `"entities:#{type}"` → EditorLive shows "Re-indexed" flash.
**DB is never written directly from LiveView.**

### LiveView routes
```
GET /                          → DashboardLive
GET /entities/:type            → EntityBrowserLive
GET /entities/:type/:id        → EntityDetailLive
GET /entities/:type/:id/edit   → EntityEditorLive
GET /maps/:id                  → MapViewerLive
GET /health                    → (simple plug, returns 200 for Docker healthcheck)
```

---

## Docker Compose

### `docker-compose.yml`
```yaml
services:
  server:
    build:
      context: ./server
      dockerfile: Dockerfile
    image: campaign-tool-server:latest
    restart: unless-stopped
    ports:
      - "4000:4000"
    environment:
      PHX_HOST: "localhost"
      PORT: "4000"
      SECRET_KEY_BASE: "${SECRET_KEY_BASE}"
      PHX_SERVER: "true"
      CAMPAIGN_DIR: "/data/campaign"
      DATABASE_PATH: "/data/db/campaign.db"
      SSH_KEY_PATH: "/run/ssh/id_ed25519"
      GIT_AUTHOR_NAME: "Campaign Tool Bot"
      GIT_AUTHOR_EMAIL: "bot@localhost"
      GIT_COMMITTER_NAME: "Campaign Tool Bot"
      GIT_COMMITTER_EMAIL: "bot@localhost"
    volumes:
      - campaign_data:/data/campaign
      - campaign_db:/data/db
      - ssh_keys:/run/ssh:ro
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  campaign_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: "${CAMPAIGN_DATA_HOST_PATH}"
  campaign_db:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: "${CAMPAIGN_DB_HOST_PATH}"
  ssh_keys:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: "${SSH_KEYS_HOST_PATH}"
```

### `.env` (gitignored)
```
SECRET_KEY_BASE=<mix phx.gen.secret>
CAMPAIGN_DATA_HOST_PATH=/home/epixors/campaign
CAMPAIGN_DB_HOST_PATH=/home/epixors/campaign-db
SSH_KEYS_HOST_PATH=/home/epixors/.ssh/campaign-tool
```

### `server/Dockerfile` (multi-stage)
- **Stage 1 (builder)**: `hexpm/elixir:1.18-erlang-27-debian-bookworm-slim`
  — `mix deps.get`, `mix assets.deploy`, `mix release`
- **Stage 2 (runtime)**: `debian:bookworm-slim`
  — copies release, installs `git openssh-client curl libssl3 libncurses6`, exposes 4000
- `docker-compose.override.yml` for dev: bind-mounts `./server:/app`, runs `mix phx.server` with `MIX_ENV=dev`

### SSH key setup (one-time, user does this on host)
```bash
mkdir -p ~/.ssh/campaign-tool
ssh-keygen -t ed25519 -f ~/.ssh/campaign-tool/id_ed25519 -C "campaign-tool" -N ""
# Add ~/.ssh/campaign-tool/id_ed25519.pub as a deploy key (write access) on your git remote
```

---

## Implementation Order

1. **Scaffold** — `mix phx.new server --no-ecto`, add deps, configure SQLite Repo, `runtime.exs`
2. **Migrations + Schemas** — 6 entity tables + FTS5 migration; 6 Ecto schemas; `StringList` type; `entities.ex` context with upsert
3. **Parser** — `Sync.Parser` with ExUnit tests against fixture `.md` files in `test/fixtures/`
4. **File watcher + IndexWorker** — `Sync.Supervisor`, `Sync.FileWatcher`, `Sync.IndexWorker`; verify: edit in Vim → DB row updated within 1s
5. **GitWorker** — test against local bare repo first; verify debounce batching
6. **Basic LiveView UI** — Dashboard, EntityBrowserLive, EntityDetailLive; PubSub auto-refresh
7. **Entity editor** — `EntityEditorLive` textarea; file write on save; re-index flash via PubSub
8. **Map viewer** — `Plug.Static` for PNG assets; `MapViewerLive` with `<img>`
9. **Search** — FTS5 queries in `Search` context; search box with `phx-debounce="300"`
10. **Docker** — Dockerfile, `docker-compose.yml`, `.env`; end-to-end test with real SSH push

---

## Verification

- Edit a `.md` file in Vim on host → browser entity detail auto-refreshes within ~1 second
- Save via web editor → file appears updated on host filesystem
- `git log` on campaign remote shows auto-commits within ~5 seconds of saves
- `docker compose up` starts cleanly; `curl localhost:4000/health` returns 200
- `docker compose down && docker compose up` — SQLite data persists (bind mount)
- Campaign files still editable from host Vim while container is running
