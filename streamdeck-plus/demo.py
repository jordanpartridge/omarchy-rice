#!/usr/bin/env python3
"""Stream Deck Plus occupancy + HID dispatcher. Complementary to Omarchy."""

from __future__ import annotations

import fcntl
import json
import os
import queue
import re
import select
import signal
import struct
import subprocess
import sys
import threading
import time
from pathlib import Path

from actions import (
    action_for_key,
    cycle_face,
    encoder_action,
    nightlight_on,
    normalize_face,
    page_dots,
    perform,
    read_volume,
    spotify_is_playing,
)

FONT = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf"
FONT_REG = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"
# Stream Deck Plus. Never assume hidrawN — the G213 often lands on hidraw1.
DECK_VID = 0x0FD9
DECK_PID = 0x0084
ROOT = Path("/home/jordan/.local/share/omarchy-streamdeck-demo")
THEME_ROOT = Path("/home/jordan/.config/omarchy/themes")
ICONS = ROOT / "icons" / "tinted"
JOB = ROOT / "jobs" / "say-the-job"
SPEC_PATH = JOB / "spec.md"
JOB_JSON = JOB / "job.json"
GROK_PROMPT = JOB / "GROK_PROMPT.md"
AGENT_PROMPT = JOB / "AGENT_PROMPT.md"
OCCUPANCY_PATH = JOB / "occupancy.json"
NIGHT_MARKERS = ("night-ready", "night-ready.md", "NIGHT_READY")
HOUSE_CHROME = ("jordan-xp", "jordan-os")
PIDFILE = ROOT / "serve.pid"
INBOX = ROOT / "inbox.jsonl"
LOG = ROOT / "serve.log"

PACKET = 1024
KEY_PAYLOAD = PACKET - 8
LCD_PAYLOAD = PACKET - 16
INPUT_SIZE = 512
KEY_COUNT = 8
ENCODER_COUNT = 4


class HidGone(Exception):
    """HID node vanished or rejected a Stream Deck report."""


def parse_hid_id(uevent: str) -> tuple[int, int] | None:
    for line in uevent.splitlines():
        if not line.startswith("HID_ID="):
            continue
        parts = line.split("=", 1)[1].strip().split(":")
        if len(parts) < 3:
            return None
        try:
            return int(parts[1], 16), int(parts[2], 16)
        except ValueError:
            return None
    return None


def find_deck_path() -> str | None:
    hidraw = Path("/sys/class/hidraw")
    if not hidraw.is_dir():
        return None
    for node in sorted(hidraw.iterdir(), key=lambda p: p.name):
        uevent = node / "device" / "uevent"
        try:
            text = uevent.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        ids = parse_hid_id(text)
        if ids == (DECK_VID, DECK_PID):
            return f"/dev/{node.name}"
    return None

THEMES = {
    "jordan-xp": {
        "label": "JORDAN XP",
        "bg": "#100C06",
        "face": "#1C160A",
        "accent": "#E8C547",
        "fg": "#FFF6D0",
        "muted": "#C4B070",
        "green": "#8FBF4A",
        "wallpaper": THEME_ROOT / "jordan-xp/backgrounds/0-bliss-mesa.jpg",
        "radius": 16,
        "stroke": 2,
        "neon": False,
    },
    "jordan-os": {
        "label": "JORDAN OS",
        "bg": "#100C06",
        "face": "#1C160A",
        "accent": "#E8C547",
        "fg": "#FFF6D0",
        "muted": "#C4B070",
        "green": "#8FBF4A",
        "wallpaper": THEME_ROOT / "jordan-xp/backgrounds/0-bliss-mesa.jpg",
        "radius": 16,
        "stroke": 2,
        "neon": False,
    },
    "skull": {
        "label": "SKULL",
        "bg": "#0a0505",
        "face": "#1a0c0c",
        "accent": "#ff1a1a",
        "fg": "#d8cfc4",
        "muted": "#6b5555",
        "green": "#ff1a1a",
        "wallpaper": THEME_ROOT / "skull/backgrounds/1-ember-close.jpg",
        "radius": 2,
        "stroke": 3,
        "neon": False,
    },
    "mudhawk": {
        "label": "MUDHAWK",
        "bg": "#1a140e",
        "face": "#2c2218",
        "accent": "#e85d04",
        "fg": "#e4d4b8",
        "muted": "#6b5344",
        "green": "#e8b923",
        "wallpaper": THEME_ROOT / "mudhawk/backgrounds/0-mud-charge.jpg",
        "radius": 8,
        "stroke": 4,
        "neon": False,
    },
    "the-shit": {
        "label": "THE SHIT",
        "bg": "#0a0a0a",
        "face": "#141414",
        "accent": "#1DB954",
        "fg": "#e1e1e1",
        "muted": "#6a6a6a",
        "green": "#1ed760",
        "wallpaper": THEME_ROOT / "the-shit/backgrounds/2-waveform.jpg",
        "radius": 0,
        "stroke": 0,
        "neon": True,
    },
}

WORKFLOWS = {
    "listen": {
        "name": "CREW",
        "knobs": ("VOL", "MIC", "LIGHT", "SEEK"),
        "ticker": "SAY THE JOB",
        "volume": 0.0,
        "keys": [
            ("GROK", "wait", "grok", "dim"),
            ("LOCAL", "wait", "local", "dim"),
            ("NIGHT", "wait", "night", "dim"),
            ("SPEC", "say it", "spec", "hot"),
            ("", "", None, "dim"),
            ("", "", None, "dim"),
            ("", "", None, "dim"),
            ("PAGE", "next", None, "idle"),
        ],
    },
    "crew": {
        "name": "CREW",
        "knobs": ("VOL", "MIC", "LIGHT", "SEEK"),
        "ticker": "ONE SENTENCE IN",
        "volume": 0.0,
        "keys": [
            ("GROK", "spec", "grok", "hot"),
            ("LOCAL", "qwen", "local", "busy"),
            ("NIGHT", "queue", "night", "idle"),
            ("SPEC", "locked", "spec", "idle"),
            ("", "", None, "dim"),
            ("", "", None, "dim"),
            ("", "", None, "dim"),
            ("PAGE", "next", None, "idle"),
        ],
    },
    "dispatch": {
        "name": "CREW",
        "knobs": ("VOL", "MIC", "LIGHT", "SEEK"),
        "ticker": "GROK LIVE",
        "volume": 0.70,
        "keys": [
            ("GROK", "live", "grok", "hot"),
            ("LOCAL", "busy", "local", "busy"),
            ("NIGHT", "idle", "night", "dim"),
            ("SPEC", "3 ready", "spec", "idle"),
            ("", "", None, "dim"),
            ("", "", None, "dim"),
            ("", "", None, "dim"),
            ("PAGE", "next", None, "idle"),
        ],
    },
    "desk": {
        "name": "DESK",
        "knobs": ("VOL", "MIC", "LIGHT", "SEEK"),
        "ticker": "MIX",
        "volume": 0.70,
        "keys": [
            ("SHOT", "still", "shot", "idle"),
            ("REC", "film", None, "idle"),
            ("MUTE", "output", None, "idle"),
            ("NITE", "warm", None, "idle"),
            ("DND", "quiet", None, "idle"),
            ("THEME", "cycle", None, "idle"),
            ("BG", "next", None, "idle"),
            ("PAGE", "next", None, "idle"),
        ],
    },
    "space": {
        "name": "SPACE",
        "knobs": ("VOL", "MIC", "LIGHT", "SEEK"),
        "ticker": "OCCUPIED",
        "volume": 0.0,
        "keys": [
            ("WS-", "prev", None, "idle"),
            ("WS+", "next", None, "idle"),
            ("WEB", "browser", None, "idle"),
            ("TERM", "shell", None, "idle"),
            ("HERDR", "session", None, "idle"),
            ("", "", None, "dim"),
            ("", "", None, "dim"),
            ("PAGE", "next", None, "idle"),
        ],
    },
    "music": {
        "name": "MUSIC",
        "knobs": ("VOL", "MIC", "LIGHT", "SEEK"),
        "ticker": "CHILL",
        "volume": 0.55,
        "keys": [
            ("CHILL", "mood", "music", "idle"),
            ("FLOW", "mood", "music", "idle"),
            ("HYPE", "mood", None, "idle"),
            ("SKIP", "next", None, "idle"),
            ("PLAY", "play", None, "idle"),
            ("LIKE", "heart", None, "idle"),
            ("MUTE", "output", None, "idle"),
            ("PAGE", "next", None, "idle"),
        ],
    },
    "sleep": {
        "name": "SLEEP",
        "knobs": ("", "", "", ""),
        "ticker": "",
        "volume": 0.0,
        "keys": [
            ("", "", None, "sleep"),
            ("", "", None, "sleep"),
            ("", "", None, "sleep"),
            ("", "", None, "sleep"),
            ("", "", None, "sleep"),
            ("", "", None, "sleep"),
            ("", "", None, "sleep"),
            ("LOCK", "sleep", "lock", "dim"),
        ],
    },
}

GLYPH_FALLBACK = {
    "MUTE": "\uf026",
    "MIC": "\uf130",
    "REC": "\uf28d",
    "THEME": "\uf185",
    "SKIP": "\uf051",
    "PAUSE": "\uf04c",
    "LIKE": "\uf004",
    "PLAY": "\uf04b",
    "HYPE": "\uf0e7",
    "FLOW": "\uf001",
    "CHILL": "\uf001",
    "PAGE": "\uf0c9",
    "WS-": "\uf060",
    "WS+": "\uf061",
    "WEB": "\uf0ac",
    "TERM": "\uf120",
    "HERDR": "\uf1b2",
    "NITE": "\uf186",
    "DND": "\uf1f6",
    "BG": "\uf03e",
}

STORY_RE = re.compile(r"^(\*\*Story:\*\*\s*).+$", re.M)


def _ioc(direction: int, type_: str, nr: int, size: int) -> int:
    return (direction << 30) | (size << 16) | (ord(type_) << 8) | nr


HIDIOCSFEATURE = _ioc(3, "H", 0x06, 32)


def magick(*args: str) -> None:
    subprocess.check_call(["magick", *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def _rect(x1: int, y1: int, x2: int, y2: int, radius: int) -> str:
    if radius <= 0:
        return f"rectangle {x1},{y1} {x2},{y2}"
    return f"roundrectangle {x1},{y1} {x2},{y2} {radius},{radius}"


def utcnow() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def normalize_theme_id(raw: str) -> str:
    return raw.strip().lower().replace("_", "-").replace(" ", "-")


def first_wallpaper(*slugs: str) -> Path:
    for slug in slugs:
        bg = THEME_ROOT / slug / "backgrounds"
        if not bg.is_dir():
            continue
        found = sorted(
            p for p in bg.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png"}
        )
        if found:
            return found[0]
    return THEME_ROOT / "jordan-xp" / "backgrounds" / "0-bliss-mesa.jpg"


def theme_pack_exists(slug: str) -> bool:
    return (THEME_ROOT / slug).is_dir()


def icon_theme_id(theme_id: str) -> str:
    if (ICONS / theme_id).is_dir():
        return theme_id
    if theme_id in HOUSE_CHROME and (ICONS / "jordan-xp").is_dir():
        return "jordan-xp"
    return theme_id


def resolve_theme(theme_id: str) -> tuple[str, dict]:
    tid = normalize_theme_id(theme_id)
    if tid not in THEMES:
        raise SystemExit(f"unknown Plus chrome: {theme_id}")
    theme = dict(THEMES[tid])
    if tid == "jordan-os":
        theme["wallpaper"] = first_wallpaper("jordan-os", "jordan-xp")
    elif not Path(theme["wallpaper"]).exists():
        theme["wallpaper"] = first_wallpaper(tid, "jordan-xp")
    theme["icon_theme"] = icon_theme_id(tid)
    return tid, theme


def map_hook_theme(slug: str) -> str | None:
    """Map an Omarchy theme-set slug onto Plus chrome. Unknown slugs skip."""
    s = normalize_theme_id(slug)
    if s in ("skull", "mudhawk", "the-shit"):
        return s
    if s == "jordan-os":
        return "jordan-os" if theme_pack_exists("jordan-os") else "jordan-xp"
    if s == "jordan-xp":
        return "jordan-xp"
    return None


def current_omarchy_theme() -> str:
    name = Path.home() / ".local/state/omarchy/current/theme.name"
    if name.exists():
        return normalize_theme_id(name.read_text(encoding="utf-8"))
    return "jordan-xp"


def default_theme() -> str:
    occ = load_occupancy()
    t = occ.get("theme")
    if isinstance(t, str) and t in THEMES:
        return t
    cur = current_omarchy_theme()
    if cur in THEMES:
        return cur
    return "jordan-xp"


def night_ready_exists() -> bool:
    for name in NIGHT_MARKERS:
        if (JOB / name).exists():
            return True
    occ = load_occupancy()
    return bool(occ.get("night_ready"))


def load_occupancy() -> dict:
    if not OCCUPANCY_PATH.is_file():
        return {}
    try:
        data = json.loads(OCCUPANCY_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def lamp_states() -> dict[str, dict[str, str]]:
    spec = SPEC_PATH.is_file()
    local = JOB_JSON.is_file()
    night = night_ready_exists()
    return {
        "GROK": {"caption": "spec" if spec else "wait", "state": "hot" if spec else "dim"},
        "LOCAL": {"caption": "qwen" if local else "wait", "state": "busy" if local else "dim"},
        "NIGHT": {"caption": "queue" if night else "idle", "state": "idle"},
        "SPEC": {"caption": "locked" if spec else "say it", "state": "idle" if spec else "hot"},
    }


def save_occupancy(**updates) -> dict:
    data = load_occupancy()
    data["job"] = "say-the-job"
    data.update(updates)
    data["lamps"] = lamp_states()
    data["updated_at"] = utcnow()
    JOB.mkdir(parents=True, exist_ok=True)
    tmp = OCCUPANCY_PATH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    tmp.replace(OCCUPANCY_PATH)
    return data


def set_spec_story(sentence: str) -> None:
    JOB.mkdir(parents=True, exist_ok=True)
    if SPEC_PATH.is_file():
        text = SPEC_PATH.read_text(encoding="utf-8")
        if STORY_RE.search(text):
            text = STORY_RE.sub(lambda m: m.group(1) + sentence, text, count=1)
        else:
            text = text.rstrip() + f"\n\n**Story:** {sentence}\n"
        SPEC_PATH.write_text(text, encoding="utf-8")
        return
    SPEC_PATH.write_text(
        "# SPEC: say-the-job occupancy\n\n"
        "Status: **DRAFT**\n"
        "Home: Thor Stream Deck Plus + Omarchy. Not a new catalog.\n\n"
        f"**Story:** {sentence}\n",
        encoding="utf-8",
    )


def write_grok_prompt(sentence: str) -> None:
    GROK_PROMPT.write_text(
        "You are Grok on Thor, `/build-spec` posture.\n\n"
        "Jordan gave one sentence. That is the whole intake.\n\n"
        f"**Sentence:** {sentence}\n\n"
        "Do:\n"
        "1. Restate it as one product intent.\n"
        "2. Map it onto existing house doors only: `/build-spec`, `/local-worker`, "
        "`/night-shift`, Omarchy `theme-set.d`. Prefer those over a new catalog.\n"
        "3. Write `jobs/say-the-job/spec.md` (DRAFT) with Story, Locked, "
        "Normative WHEN/SHALL, Acceptance checkboxes, Non-goals.\n"
        "4. Write `AGENT_PROMPT.md` for the typer that would execute that SPEC. "
        "If there is no allowlist and test yet, say “not ready to type” and stop.\n"
        "5. Stop. Do not implement. Do not dispatch. Do not merge. "
        "`--max-turns` stays bounded.\n\n"
        "Do not: StreamController, a plugin store, Qdrant-as-truth, a second GPU, "
        "standing loops, `gh pr merge`.\n",
        encoding="utf-8",
    )


def write_agent_prompt(sentence: str) -> None:
    envelope: dict = {}
    if JOB_JSON.is_file():
        try:
            loaded = json.loads(JOB_JSON.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                envelope = loaded
        except (OSError, json.JSONDecodeError):
            envelope = {}
    allowlist = envelope.get("allowlist") if isinstance(envelope.get("allowlist"), list) else []
    test = envelope.get("test") if isinstance(envelope.get("test"), str) else ""
    if not allowlist or not test:
        AGENT_PROMPT.write_text(
            f"SPEC path: `jobs/say-the-job/spec.md`.\n\n"
            f"Occupancy ticker: {sentence}\n\n"
            "not ready to type.\n\n"
            "Do not implement. Do not call `dispatch.sh`. Do not `gh pr merge`.\n",
            encoding="utf-8",
        )
        return
    listed = "\n".join(f"   - `{item}`" for item in allowlist)
    AGENT_PROMPT.write_text(
        "Implement SPEC `jobs/say-the-job/spec.md` exactly. Occupancy lamps "
        "plus HID key-up actions on `--serve`. Do not auto-dispatch GPU.\n\n"
        "You are a local Ollama coding agent (`qwen-coder-32k`). Allowlist only.\n\n"
        "Do:\n"
        "1. Read the spec. Do not invent HID features past occupancy lamps.\n"
        f"2. Occupancy ticker: {sentence}\n"
        "3. If you touch code, stay inside the allowlist:\n"
        f"{listed}\n"
        f"4. Prove: `{test}` exits 0 and leaves CREW on hidraw1.\n"
        "5. Stop. Do not commit. Do not push. Do not call `dispatch.sh` yourself.\n\n"
        "Do not: SSH, merge, deploy, StreamController, extra faces, Wine Elgato "
        "software, `gh pr merge`.\n",
        encoding="utf-8",
    )


def write_intent(sentence: str) -> None:
    """Update say-the-job occupancy. Do not dispatch. Do not GPU."""
    sentence = " ".join(sentence.split())
    set_spec_story(sentence)
    write_grok_prompt(sentence)
    write_agent_prompt(sentence)
    save_occupancy(
        face="crew",
        theme=default_theme(),
        ticker=sentence,
        intent=sentence,
        night_ready=night_ready_exists(),
    )


def occupancy_face(occ: dict, fallback: str = "crew") -> str:
    raw = occ.get("face")
    if raw in WORKFLOWS:
        return normalize_face(str(raw))
    return fallback


def occupancy_ticker(fallback: str) -> str:
    ticker = load_occupancy().get("ticker")
    if isinstance(ticker, str) and ticker.strip():
        return ticker.strip()[:48]
    return fallback


def workflow_with_occupancy(workflow_id: str, ticker: str | None) -> dict:
    workflow = dict(WORKFLOWS[workflow_id])
    workflow["keys"] = [tuple(spec) for spec in workflow["keys"]]
    if ticker:
        workflow["ticker"] = ticker[:48]
    elif workflow_id in ("crew", "listen"):
        workflow["ticker"] = occupancy_ticker(str(workflow["ticker"]))

    if workflow_id not in ("crew", "listen"):
        return workflow

    lamps = lamp_states()
    keys = list(workflow["keys"])
    grok = lamps["GROK"]
    local = lamps["LOCAL"]
    night = lamps["NIGHT"]
    spec = lamps["SPEC"]
    keys[0] = ("GROK", grok["caption"], "grok", grok["state"])
    keys[1] = ("LOCAL", local["caption"], "local", local["state"])
    keys[2] = ("NIGHT", night["caption"], "night", night["state"])
    keys[3] = ("SPEC", spec["caption"], "spec", spec["state"])
    workflow["keys"] = keys
    return workflow


def footer_for(workflow_id: str) -> str:
    if workflow_id == "sleep":
        return "sleep · lock armed · encoder wake"
    if workflow_id in ("crew", "listen"):
        return "crew · occupancy on disk · keys live"
    return f"{workflow_id} · keys live · swipe pages"


def render_sleep_key(path: Path, theme: dict, title: str, icon: str | None) -> None:
    args = [
        str(theme["wallpaper"]),
        "-resize",
        "120x120^",
        "-gravity",
        "center",
        "-crop",
        "120x120+0+0",
        "+repage",
        "-fill",
        "rgba(0,0,0,0.62)",
        "-draw",
        "rectangle 0,0 120,120",
        "-modulate",
        "70,80",
    ]
    magick(*args, "-quality", "88", str(path))


def render_key(
    path: Path,
    theme: dict,
    theme_id: str,
    title: str,
    caption: str,
    icon: str | None,
    state: str,
) -> None:
    if state == "sleep" and not title:
        magick(
            str(theme["wallpaper"]),
            "-resize",
            "120x120^",
            "-gravity",
            "center",
            "-crop",
            "120x120+0+0",
            "+repage",
            "-fill",
            "rgba(0,0,0,0.62)",
            "-draw",
            "rectangle 0,0 120,120",
            "-modulate",
            "65,75",
            "-quality",
            "88",
            str(path),
        )
        return

    radius = theme["radius"]
    stroke = theme["stroke"]
    face = theme["face"]
    house = theme_id in HOUSE_CHROME
    accent = theme["green"] if (title == "LOCK" and house) else theme["accent"]
    if state == "hot":
        face = theme["accent"]
        label_color = theme["bg"]
        cap_color = theme["bg"]
        icon_fill = theme["bg"]
    elif state == "dim":
        accent = theme["muted"]
        label_color = theme["muted"]
        cap_color = theme["muted"]
        icon_fill = theme["muted"]
        face = theme["bg"]
    elif state == "busy":
        label_color = theme["fg"]
        cap_color = theme["accent"]
        icon_fill = theme["accent"]
    else:
        label_color = theme["fg"]
        cap_color = theme["muted"]
        icon_fill = accent

    if state == "hot":
        face = theme["face"]
        label_color = theme["fg"]
        cap_color = theme["accent"]
        icon_fill = accent

    args = ["-size", "120x120", f"xc:{theme['bg']}", "-fill", face, "-draw", _rect(6, 6, 113, 113, radius)]
    if theme["neon"]:
        args += ["-fill", accent, "-draw", "rectangle 6,6 113,8"]
    elif stroke:
        args += [
            "-fill",
            "none",
            "-stroke",
            accent,
            "-strokewidth",
            str(stroke),
            "-draw",
            _rect(8, 8, 111, 111, max(radius - 2, 0)),
            "-stroke",
            "none",
        ]
    if state == "hot":
        args += ["-fill", accent, "-draw", _rect(22, 10, 97, 16, 2)]

    icon_root = ICONS / theme.get("icon_theme", theme_id)
    icon_file = icon_root / f"{icon}.png" if icon else None
    tmp = path.with_suffix(".work.png")
    magick(*args, str(tmp))

    compose = [str(tmp)]
    if icon_file and icon_file.exists():
        tinted = path.with_suffix(".icon.png")
        fill = icon_fill
        magick(
            str(icon_file),
            "-fill",
            fill,
            "-colorize",
            "100",
            str(tinted),
        )
        compose += [str(tinted), "-gravity", "north", "-geometry", "+0+16", "-composite"]
    elif title in GLYPH_FALLBACK or (title == "PLAY" and "PAUSE" in GLYPH_FALLBACK):
        glyph = GLYPH_FALLBACK["PAUSE"] if title == "PLAY" and state == "hot" else GLYPH_FALLBACK.get(title, "")
        magick(
            str(tmp),
            "-font",
            FONT,
            "-fill",
            icon_fill,
            "-pointsize",
            "30",
            "-gravity",
            "north",
            "-annotate",
            "+0+18",
            glyph,
            str(tmp),
        )
        compose = [str(tmp)]

    magick(
        *compose,
        "-font",
        FONT,
        "-fill",
        label_color,
        "-pointsize",
        "13",
        "-gravity",
        "center",
        "-annotate",
        "+0+28",
        title,
        "-font",
        FONT_REG,
        "-fill",
        cap_color,
        "-pointsize",
        "9",
        "-annotate",
        "+0+44",
        caption,
        "-quality",
        "92",
        str(path),
    )
    for leftover in (tmp, path.with_suffix(".icon.png")):
        if leftover.exists() and leftover != path:
            leftover.unlink()


def render_strip(path: Path, theme: dict, workflow: dict, workflow_id: str = "") -> None:
    knobs = workflow["knobs"]
    volume = float(workflow.get("volume") or 0)
    ticker = workflow.get("ticker") or ""
    overlay = [
        str(theme["wallpaper"]),
        "-resize",
        "800x",
        "-gravity",
        "center",
        "-crop",
        "800x100+0+0",
        "+repage",
        "-fill",
        "rgba(0,0,0,0.50)",
        "-draw",
        "rectangle 0,0 800,100",
        "-fill",
        "rgba(0,0,0,0.40)",
        "-draw",
        "rectangle 0,70 800,100",
    ]
    for x in (200, 400, 600):
        overlay += ["-fill", "rgba(255,255,255,0.12)", "-draw", f"line {x},72 {x},98"]
    if volume > 0:
        w = int(188 * volume)
        overlay += ["-fill", theme["accent"] + "99", "-draw", f"rectangle 6,86 {6 + w},96"]

    overlay += [
        "-font",
        FONT,
        "-fill",
        theme["fg"],
        "-pointsize",
        "20",
        "-gravity",
        "northwest",
        "-annotate",
        "+16+12",
        (f"{workflow['name']}   {page_dots(workflow_id)}" if page_dots(workflow_id) else workflow["name"]),
        "-font",
        FONT_REG,
        "-fill",
        theme["accent"],
        "-pointsize",
        "12",
        "-annotate",
        "+16+36",
        ticker,
        "-gravity",
        "northeast",
        "-annotate",
        "+16+18",
        theme["label"],
        "-font",
        FONT,
        "-fill",
        theme["muted"],
        "-pointsize",
        "11",
        "-gravity",
        "northwest",
        "-annotate",
        "+70+78",
        knobs[0],
        "-annotate",
        "+270+78",
        knobs[1],
        "-annotate",
        "+470+78",
        knobs[2],
        "-annotate",
        "+670+78",
        knobs[3],
        "-quality",
        "90",
        str(path),
    ]
    magick(*overlay)


def render_preview(path: Path, theme: dict, workflow_id: str, key_dir: Path, strip: Path) -> None:
    grid = path.with_name("grid.jpg")
    subprocess.check_call(
        [
            "magick",
            "montage",
            *[str(key_dir / f"{i}.jpg") for i in range(8)],
            "-tile",
            "4x2",
            "-geometry",
            "188x188+8+8",
            "-background",
            theme["bg"],
            str(grid),
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    magick(
        "-size",
        "840x560",
        f"xc:{theme['bg']}",
        str(grid),
        "-gravity",
        "north",
        "-geometry",
        "+0+16",
        "-composite",
        str(strip),
        "-gravity",
        "north",
        "-geometry",
        "+0+428",
        "-composite",
        "-font",
        FONT_REG,
        "-fill",
        theme["muted"],
        "-pointsize",
        "11",
        "-gravity",
        "south",
        "-annotate",
        "+0+10",
        footer_for(workflow_id),
        "-quality",
        "90",
        str(path),
    )


def render_face(theme_id: str, workflow_id: str, ticker: str | None = None) -> Path:
    theme_id, theme = resolve_theme(theme_id)
    workflow = workflow_with_occupancy(workflow_id, ticker)
    out = ROOT / "faces" / f"{workflow_id}-{theme_id}"
    keys = out / "keys"
    keys.mkdir(parents=True, exist_ok=True)
    for i, spec in enumerate(workflow["keys"]):
        title, caption, icon, state = spec
        render_key(keys / f"{i}.jpg", theme, theme_id, title, caption, icon, state)
    strip = out / "strip.jpg"
    render_strip(strip, theme, workflow, workflow_id)
    render_preview(out / "preview.jpg", theme, workflow_id, keys, strip)
    return out


def set_brightness(fd: int, percent: int) -> None:
    buf = bytearray(32)
    buf[0:3] = bytes([0x03, 0x08, max(0, min(100, percent))])
    fcntl.ioctl(fd, HIDIOCSFEATURE, buf)


def set_key_image(fd: int, key: int, jpeg: bytes) -> None:
    page = 0
    remaining = len(jpeg)
    while remaining > 0:
        this_len = min(remaining, KEY_PAYLOAD)
        sent = page * KEY_PAYLOAD
        last = 1 if this_len == remaining else 0
        header = bytes(
            [
                0x02,
                0x07,
                key & 0xFF,
                last,
                this_len & 0xFF,
                (this_len >> 8) & 0xFF,
                page & 0xFF,
                (page >> 8) & 0xFF,
            ]
        )
        chunk = jpeg[sent : sent + this_len]
        report = header + chunk + bytes(PACKET - len(header) - len(chunk))
        os.write(fd, report)
        remaining -= this_len
        page += 1


def set_touchscreen_image(fd: int, jpeg: bytes) -> None:
    width, height = 800, 100
    page = 0
    remaining = len(jpeg)
    while remaining > 0:
        this_len = min(remaining, LCD_PAYLOAD)
        sent = page * LCD_PAYLOAD
        last = 1 if this_len == remaining else 0
        header = bytes(
            [
                0x02,
                0x0C,
                0,
                0,
                0,
                0,
                width & 0xFF,
                (width >> 8) & 0xFF,
                height & 0xFF,
                (height >> 8) & 0xFF,
                last,
                page & 0xFF,
                (page >> 8) & 0xFF,
                this_len & 0xFF,
                (this_len >> 8) & 0xFF,
                0x00,
            ]
        )
        chunk = jpeg[sent : sent + this_len]
        report = header + chunk + bytes(PACKET - len(header) - len(chunk))
        os.write(fd, report)
        remaining -= this_len
        page += 1


def push_face(fd: int, face: Path) -> None:
    for i in range(8):
        jpeg = (face / "keys" / f"{i}.jpg").read_bytes()
        set_key_image(fd, i, jpeg)
    set_touchscreen_image(fd, (face / "strip.jpg").read_bytes())


def open_hid(*, fail_soft: bool, path: str | None = None) -> int | None:
    path = path or find_deck_path()
    if not path:
        if fail_soft:
            print("hidraw skip: Stream Deck Plus (0fd9:0084) not present", file=sys.stderr)
            return None
        raise FileNotFoundError("Stream Deck Plus (0fd9:0084) not present")
    try:
        fd = os.open(path, os.O_RDWR)
    except OSError as exc:
        if fail_soft:
            print(f"hidraw skip {path}: {exc}", file=sys.stderr)
            return None
        raise
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        os.close(fd)
        if fail_soft:
            print(f"hidraw busy {path}; skip push", file=sys.stderr)
            return None
        raise
    return fd


def parse_input(data: bytes) -> list[tuple]:
    """Parse a Stream Deck Plus HID input report (report id 0x01)."""
    if not data or data[0] != 0x01 or len(data) < 5:
        return []
    cmd = data[1]
    events: list[tuple] = []
    if cmd == 0x00:
        states = tuple(bool(b) for b in data[4 : 4 + KEY_COUNT])
        if len(states) == KEY_COUNT:
            events.append(("key_state", states))
        return events
    if cmd == 0x02:
        kind = data[4]
        if kind in (0x01, 0x02) and len(data) >= 10:
            x, y = struct.unpack_from("<HH", data, 6)
            name = "tap" if kind == 0x01 else "hold"
            events.append((name, (int(x), int(y))))
        elif kind == 0x03 and len(data) >= 14:
            x1, y1, x2, y2 = struct.unpack_from("<HHHH", data, 6)
            events.append(("flick", (int(x1), int(y1), int(x2), int(y2))))
        return events
    if cmd == 0x03:
        kind = data[4]
        payload = data[5 : 5 + ENCODER_COUNT]
        if kind == 0x00:
            events.append(("enc_state", tuple(bool(b) for b in payload)))
        elif kind == 0x01:
            ticks = tuple(
                struct.unpack("b", bytes([b]))[0] if isinstance(b, int) else 0
                for b in payload
            )
            events.append(("enc_twist", ticks))
        return events
    return events


def serve_alive() -> int | None:
    if not PIDFILE.is_file():
        return None
    try:
        pid = int(PIDFILE.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return None
    try:
        os.kill(pid, 0)
    except OSError:
        return None
    return pid


def write_inbox(event: dict) -> None:
    INBOX.parent.mkdir(parents=True, exist_ok=True)
    line = json.dumps(event) + "\n"
    with INBOX.open("a", encoding="utf-8") as fh:
        fh.write(line)


def drain_inbox() -> list[dict]:
    if not INBOX.is_file():
        return []
    taking = INBOX.with_suffix(".jsonl.taking")
    try:
        INBOX.replace(taking)
    except OSError:
        return []
    events: list[dict] = []
    try:
        for line in taking.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(item, dict):
                events.append(item)
    finally:
        taking.unlink(missing_ok=True)
    return events


def title_for_key(face: str, index: int) -> str:
    keys = WORKFLOWS.get(face, {}).get("keys") or []
    if 0 <= index < len(keys):
        return str(keys[index][0] or "")
    return ""


def self_test() -> int:
    failed = 0

    def check(cond: bool, label: str) -> None:
        nonlocal failed
        if cond:
            print(f"ok  {label}")
        else:
            failed += 1
            print(f"FAIL {label}")

    press = bytes([0x01, 0x00, 0x08, 0x00, 0, 0, 0, 1, 0, 0, 0, 0])
    ev = parse_input(press)
    check(ev == [("key_state", (False, False, False, True, False, False, False, False))], "parse key 3 down")
    check(
        parse_hid_id("HID_ID=0003:00000FD9:00000084\n") == (DECK_VID, DECK_PID),
        "parse Stream Deck Plus hid id",
    )
    check(
        parse_hid_id("HID_ID=0003:0000046D:0000C336\n") != (DECK_VID, DECK_PID),
        "G213 is not the Plus",
    )

    rel = bytes([0x01, 0x00, 0x08, 0x00, 0, 0, 0, 0, 0, 0, 0, 0])
    check(parse_input(rel) == [("key_state", (False,) * 8)], "parse key up")

    twist = bytes([0x01, 0x03, 0x05, 0x00, 0x01, 0x02, 0x00, 0x00, 0xFF])
    ev = parse_input(twist)
    check(ev and ev[0][0] == "enc_twist" and ev[0][1][0] == 2 and ev[0][1][3] == -1, "parse encoder twist")

    tap = bytes([0x01, 0x02, 0x0A, 0x00, 0x01, 0x00, 0x64, 0x00, 0x32, 0x00])
    ev = parse_input(tap)
    check(ev == [("tap", (100, 50))], "parse tap")

    flick = bytes([0x01, 0x02, 0x0E, 0x00, 0x03, 0x00, 0x10, 0x00, 0x32, 0x00, 0xC8, 0x01, 0x32, 0x00])
    ev = parse_input(flick)
    check(ev and ev[0][0] == "flick" and ev[0][1][2] == 456, "parse flick")

    check(action_for_key("listen", "SPEC") == "spec_capture", "listen SPEC captures")
    check(action_for_key("crew", "SPEC") == "spec_capture", "crew SPEC captures")
    check(action_for_key("desk", "SHOT") == "shot", "desk SHOT")
    check(action_for_key("music", "CHILL") == "mood_chill", "music CHILL")
    check(action_for_key("sleep", "LOCK") == "wake_crew", "sleep LOCK wakes")
    check(encoder_action(0, ticks=1) == "vol_up", "knob 0 vol up")
    check(encoder_action(3, ticks=-1) == "skip_prev", "knob 3 seek prev")
    check(cycle_face("crew", 1) == "music", "face cycle crew→music")
    check(cycle_face("music", 1) == "desk", "face cycle music→desk")
    check(cycle_face("desk", 1) == "space", "face cycle desk→space")
    check(action_for_key("music", "PLAY") == "play_toggle", "play is a toggle")
    check(action_for_key("music", "PAUSE") is None, "no separate pause key")
    check(action_for_key("desk", "PAGE") == "face_next", "PAGE turns the page")
    check(action_for_key("space", "WS+") == "ws_next", "space WS+")
    check(map_hook_theme("aether") is None, "unknown theme skip")
    check(map_hook_theme("jordan-os") in {"jordan-os", "jordan-xp"}, "jordan-os maps")

    dry = perform("shot", dry_run=True)
    check(dry.ok and "screenshot" in dry.message, "dry shot")
    dry = perform("local_dispatch", dry_run=True)
    check(dry.ok, "dry local (occupancy or spawn)")
    dry = perform("spec_capture", dry_run=True)
    check(dry.face == "crew" and dry.paint, "dry spec")
    dry = perform("lock", dry_run=True)
    check(dry.lock_after and dry.face == "sleep", "dry lock")

    grok = GROK_PROMPT.read_text(encoding="utf-8")
    check("Do not:" in grok and "gh pr merge" in grok, "grok forbids merge")
    check(encoder_action(1, ticks=1) is None, "mic knob rotate is inert")
    return 1 if failed else 0


class DeckServer:
    def __init__(self, fd: int, *, dry_run: bool = False) -> None:
        occ = load_occupancy()
        face = occupancy_face(occ)
        theme = occ.get("theme") if occ.get("theme") in THEMES else default_theme()
        self.fd = fd
        self.dry_run = dry_run
        self.face = str(face)
        self.theme = str(theme)
        self.ticker = occupancy_ticker("")
        self.keys = [False] * KEY_COUNT
        self.enc = [False] * ENCODER_COUNT
        self.recording = bool(occ.get("recording"))
        self.stop = False
        self.busy = threading.Lock()
        self.paints: queue.SimpleQueue[str] = queue.SimpleQueue()
        self._theme_mtime = 0.0
        self._occ_mtime = 0.0
        self._last_lamp = ""

    def log(self, msg: str) -> None:
        line = f"{utcnow()} {msg}"
        print(line, flush=True)
        try:
            with LOG.open("a", encoding="utf-8") as fh:
                fh.write(line + "\n")
        except OSError:
            pass

    def current_volume(self) -> float:
        vol, muted = read_volume()
        return 0.0 if muted else vol

    def paint(self, face: str | None = None, ticker: str | None = None) -> None:
        if face:
            self.face = face
        if ticker is not None:
            self.ticker = ticker
        workflow = workflow_with_occupancy(self.face, self.ticker or None)
        vol = self.current_volume()
        if vol or self.face in ("desk", "music", "dispatch"):
            workflow["volume"] = vol
        if self.face == "music":
            keys = list(workflow["keys"])
            playing = spotify_is_playing()
            mood = (self.ticker or "").lower()
            for i, spec in enumerate(keys):
                title, caption, icon, state = spec
                if title in ("CHILL", "FLOW", "HYPE"):
                    keys[i] = (title, caption, icon, "hot" if title.lower() == mood else "idle")
                elif title == "PLAY":
                    keys[i] = ("PLAY", "pause" if playing else "play", None, "hot" if playing else "idle")
            workflow["keys"] = keys
        if self.face == "desk":
            keys = list(workflow["keys"])
            _vol, muted = read_volume()
            nite = nightlight_on()
            for i, spec in enumerate(keys):
                title, caption, icon, state = spec
                if title == "REC" and self.recording:
                    keys[i] = ("REC", "film", None, "hot")
                elif title == "MUTE":
                    keys[i] = ("MUTE", "muted" if muted else "output", None, "busy" if muted else "idle")
                elif title == "NITE":
                    keys[i] = ("NITE", "on" if nite else "warm", None, "hot" if nite else "idle")
            workflow["keys"] = keys
        out = ROOT / "faces" / f"{self.face}-{self.theme}"
        keys_dir = out / "keys"
        keys_dir.mkdir(parents=True, exist_ok=True)
        theme_id, theme = resolve_theme(self.theme)
        self.theme = theme_id
        for i, spec in enumerate(workflow["keys"]):
            title, caption, icon, state = spec
            render_key(keys_dir / f"{i}.jpg", theme, theme_id, title, caption, icon, state)
        strip = out / "strip.jpg"
        render_strip(strip, theme, workflow, self.face)
        render_preview(out / "preview.jpg", theme, self.face, keys_dir, strip)
        try:
            set_brightness(self.fd, 35 if self.face == "sleep" else 100)
            push_face(self.fd, out)
        except (BrokenPipeError, OSError) as exc:
            self.log(f"hid write failed: {exc}")
            raise HidGone from exc
        save_occupancy(
            face=self.face,
            theme=self.theme,
            ticker=self.ticker,
            recording=self.recording,
        )
        try:
            self._occ_mtime = OCCUPANCY_PATH.stat().st_mtime
        except OSError:
            pass
        self._last_lamp = json.dumps(lamp_states(), sort_keys=True)
        self.log(f"paint {self.face} · {self.theme}")

    def apply(self, result) -> None:
        if result.recording is not None:
            self.recording = bool(result.recording)
        if result.ticker:
            self.ticker = result.ticker
        if result.mood:
            self.ticker = result.mood.upper()
        if result.lock_after:
            if result.face:
                self.paint(result.face, result.ticker)
            if not self.dry_run:
                subprocess.Popen(
                    ["omarchy", "system", "lock"],
                    start_new_session=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            return
        if result.paint or result.face:
            self.paint(result.face or self.face, result.ticker if result.ticker else None)

    def fire(self, name: str) -> None:
        if not name:
            return
        if name == "face_next":
            self.paint(cycle_face(self.face, 1))
            return
        if not self.busy.acquire(blocking=False):
            self.log(f"busy, skip {name}")
            return

        def worker() -> None:
            try:
                self.log(f"action {name}")
                result = perform(
                    name,
                    dry_run=self.dry_run,
                    write_intent=write_intent,
                    current_theme=self.theme,
                    recording=self.recording,
                    night_ready=night_ready_exists(),
                )
                self.log(result.message)
                self.paints.put(result)
            finally:
                self.busy.release()

        threading.Thread(target=worker, daemon=True).start()

    def on_key_release(self, index: int) -> None:
        title = title_for_key(self.face, index)
        name = action_for_key(self.face, title)
        if name:
            self.fire(name)

    def on_encoder(self, index: int, *, ticks: int = 0, pressed: bool = False) -> None:
        name = encoder_action(index, ticks=ticks, pressed=pressed)
        if name:
            self.fire(name)

    def on_tap(self, x: int, y: int) -> None:
        col = min(3, max(0, x // 200))
        self.on_encoder(col, pressed=True)

    def on_flick(self, x1: int, _y1: int, x2: int, _y2: int) -> None:
        dx = x2 - x1
        if abs(dx) < 80:
            return
        nxt = cycle_face(self.face, 1 if dx > 0 else -1)
        self.paint(nxt)

    def on_hold(self, _x: int, _y: int) -> None:
        self.fire("lock")

    def handle_hid(self, data: bytes) -> None:
        for kind, payload in parse_input(data):
            if kind == "key_state":
                for i, down in enumerate(payload):
                    if self.keys[i] and not down:
                        self.on_key_release(i)
                    self.keys[i] = down
            elif kind == "enc_state":
                for i, down in enumerate(payload):
                    if self.enc[i] and not down:
                        self.on_encoder(i, pressed=True)
                    if i < len(self.enc):
                        self.enc[i] = down
            elif kind == "enc_twist":
                for i, ticks in enumerate(payload):
                    if ticks:
                        self.on_encoder(i, ticks=int(ticks))
            elif kind == "tap":
                self.on_tap(*payload)
            elif kind == "hold":
                self.on_hold(*payload)
            elif kind == "flick":
                self.on_flick(*payload)

    def handle_inbox_item(self, item: dict) -> None:
        typ = str(item.get("type") or "")
        if typ == "press":
            name = str(item.get("name") or "").upper()
            action = action_for_key(self.face, name) or {
                "SPEC": "spec_capture" if self.face == "listen" else "face_listen",
                "LOCK": "lock",
                "SHOT": "shot",
                "MUSIC": "face_music",
                "FLEET": "fleet_brief",
                "LOCAL": "local_dispatch",
                "MUTE": "mute",
                "SKIP": "skip",
                "CREW": "face_crew",
                "LISTEN": "face_listen",
                "DESK": "face_desk",
            }.get(name)
            if action:
                self.fire(action)
        elif typ == "key":
            self.on_key_release(int(item.get("index") or 0))
        elif typ == "knob":
            self.on_encoder(int(item.get("index") or 0), ticks=int(item.get("ticks") or 0))
        elif typ == "knob_press":
            self.on_encoder(int(item.get("index") or 0), pressed=True)
        elif typ == "tap":
            self.on_tap(int(item.get("x") or 0), int(item.get("y") or 0))
        elif typ == "flick":
            self.on_flick(
                int(item.get("x1") or 0),
                int(item.get("y1") or 0),
                int(item.get("x2") or 0),
                int(item.get("y2") or 0),
            )
        elif typ == "hold":
            self.fire("lock")

    def watch_files(self) -> None:
        theme_path = Path.home() / ".local/state/omarchy/current/theme.name"
        try:
            mtime = theme_path.stat().st_mtime if theme_path.is_file() else 0.0
        except OSError:
            mtime = 0.0
        if mtime and mtime != self._theme_mtime:
            self._theme_mtime = mtime
            mapped = map_hook_theme(current_omarchy_theme())
            if mapped and mapped != self.theme:
                self.theme = mapped
                self.paint()
        lamps = json.dumps(lamp_states(), sort_keys=True)
        if lamps != self._last_lamp and self.face in ("crew", "listen", "dispatch"):
            self.paint()
            return
        try:
            occ_m = OCCUPANCY_PATH.stat().st_mtime if OCCUPANCY_PATH.is_file() else 0.0
        except OSError:
            occ_m = 0.0
        if occ_m and occ_m != self._occ_mtime:
            self._occ_mtime = occ_m
            occ = load_occupancy()
            face = occupancy_face(occ, self.face)
            theme = occ.get("theme") if occ.get("theme") in THEMES else self.theme
            ticker = occ.get("ticker") if isinstance(occ.get("ticker"), str) else self.ticker
            rec = bool(occ.get("recording"))
            if (
                str(face) != self.face
                or str(theme) != self.theme
                or str(ticker) != self.ticker
                or rec != self.recording
            ):
                self.face = str(face)
                self.theme = str(theme)
                self.ticker = str(ticker or "")
                self.recording = rec
                self.paint()

    def loop(self) -> None:
        path = find_deck_path() or "?"
        PIDFILE.write_text(str(os.getpid()) + "\n", encoding="utf-8")
        self.log(f"serve pid {os.getpid()} on {path}")
        self.paint()
        theme_path = Path.home() / ".local/state/omarchy/current/theme.name"
        try:
            self._theme_mtime = theme_path.stat().st_mtime if theme_path.is_file() else 0.0
        except OSError:
            self._theme_mtime = 0.0
        try:
            while not self.stop:
                try:
                    ready, _, _ = select.select([self.fd], [], [], 0.25)
                except (InterruptedError, ValueError, OSError) as exc:
                    raise HidGone from exc
                if ready:
                    try:
                        data = os.read(self.fd, INPUT_SIZE)
                    except BlockingIOError:
                        data = b""
                    except OSError as exc:
                        raise HidGone from exc
                    if data:
                        self.handle_hid(data)
                for item in drain_inbox():
                    self.handle_inbox_item(item)
                while True:
                    try:
                        result = self.paints.get_nowait()
                    except queue.Empty:
                        break
                    self.apply(result)
                self.watch_files()
        finally:
            PIDFILE.unlink(missing_ok=True)
            self.log("serve stop")


def run_press(name: str, *, dry_run: bool) -> int:
    name = name.strip().upper()
    pid = serve_alive()
    if pid and not dry_run:
        write_inbox({"type": "press", "name": name, "ts": utcnow()})
        print(f"inbox ← press {name} (serve {pid})")
        return 0
    occ = load_occupancy()
    face = occupancy_face(occ)
    named = {
        "SPEC": "spec_capture",
        "LOCK": "lock",
        "SHOT": "shot",
        "MUSIC": "face_music",
        "FLEET": "fleet_brief",
        "LOCAL": "local_dispatch",
        "NIGHT": "night_status",
        "MUTE": "mute",
        "MIC": "mic",
        "SKIP": "skip",
        "PLAY": "play",
        "PAUSE": "pause",
        "THEME": "theme_cycle",
        "CREW": "face_crew",
        "LISTEN": "face_listen",
        "DESK": "face_desk",
        "PAGE": "face_next",
        "SPACE": "face_space",
        "CHILL": "mood_chill",
        "FLOW": "mood_flow",
        "HYPE": "mood_hype",
        "REC": "rec_toggle",
    }
    action = named.get(name) or action_for_key(str(face), name)
    if not action:
        raise SystemExit(f"unknown press {name!r} on face {face}")
    result = perform(
        action,
        dry_run=dry_run,
        write_intent=write_intent,
        current_theme=default_theme(),
        recording=bool(occ.get("recording")),
        night_ready=night_ready_exists(),
    )
    print(result.message)
    if dry_run:
        return 0 if result.ok else 1
    if result.ticker:
        save_occupancy(ticker=result.ticker, face=result.face or face)
    if result.lock_after:
        subprocess.Popen(
            ["omarchy", "system", "lock"],
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    return 0 if result.ok else 1


def main() -> int:
    ROOT.mkdir(parents=True, exist_ok=True)
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    if dry_run:
        args = [a for a in args if a != "--dry-run"]
    if "--self-test" in args:
        return self_test()
    if "--press" in args:
        i = args.index("--press")
        name = args[i + 1] if i + 1 < len(args) else ""
        if not name:
            raise SystemExit("usage: demo.py --press <KEY>")
        return run_press(name, dry_run=dry_run)
    if "--serve" in args:
        pid = serve_alive()
        if pid:
            raise SystemExit(f"already serving as pid {pid}")
        server: DeckServer | None = None
        fd: int | None = None
        stopped = False

        def _stop(_signum=None, _frame=None) -> None:
            nonlocal stopped
            stopped = True
            if server is not None:
                server.stop = True

        signal.signal(signal.SIGTERM, _stop)
        signal.signal(signal.SIGINT, _stop)
        try:
            while not stopped:
                path = find_deck_path()
                if not path:
                    print("waiting for Stream Deck Plus (0fd9:0084)", flush=True)
                    time.sleep(2)
                    continue
                try:
                    fd = open_hid(fail_soft=False, path=path)
                except OSError as exc:
                    print(f"open {path}: {exc}", flush=True)
                    time.sleep(2)
                    continue
                os.set_blocking(fd, False)
                if server is None:
                    server = DeckServer(fd, dry_run=dry_run)
                else:
                    server.fd = fd
                    server.stop = False
                try:
                    server.loop()
                except HidGone:
                    try:
                        os.close(fd)
                    except OSError:
                        pass
                    fd = None
                    time.sleep(1)
                    continue
                break
        finally:
            if fd is not None:
                try:
                    os.close(fd)
                except OSError:
                    pass
        return 0
    ticker = None
    fail_soft = bool(serve_alive())
    skip = False
    if "--intent" in args:
        i = args.index("--intent")
        ticker = " ".join(args[i + 1 :]).strip() or None
        args = args[:i]
        if ticker:
            write_intent(ticker)
            print(f"occupancy ← {ticker}")
    if "--theme-set" in args:
        i = args.index("--theme-set")
        slug = args[i + 1] if i + 1 < len(args) else ""
        mapped = map_hook_theme(slug)
        fail_soft = True
        occ = load_occupancy()
        face = occupancy_face(occ)
        ticker = ticker or (occ.get("ticker") if isinstance(occ.get("ticker"), str) else None)
        if mapped is None:
            print(f"theme {slug!r} has no Plus chrome; skip")
            skip = True
            sequence: list[tuple[str, str]] = []
            hold = 0
        else:
            sequence = [(str(face), mapped)]
            hold = 0
    elif "--listen" in args:
        sequence = [("listen", default_theme()), ("crew", default_theme())]
        hold = 3.5
    elif "--face" in args:
        i = args.index("--face")
        if i + 2 >= len(args):
            raise SystemExit("usage: demo.py --face <workflow> <theme>")
        sequence = [(args[i + 1], args[i + 2])]
        hold = 0
    elif "--cycle" in args:
        sequence = [
            ("listen", "jordan-xp"),
            ("crew", "jordan-xp"),
            ("dispatch", "jordan-xp"),
            ("dispatch", "skull"),
            ("sleep", "jordan-xp"),
            ("crew", "jordan-xp"),
        ]
        hold = 4.8
    else:
        sequence = [("crew", default_theme())]
        hold = 0

    if skip:
        return 0

    print("rendering faces…")
    faces = {}
    for workflow_id, theme_id in sequence:
        key = (workflow_id, theme_id, ticker)
        if key not in faces:
            faces[key] = render_face(theme_id, workflow_id, ticker)
            print(f"  {workflow_id} / {theme_id}")

    fd = open_hid(fail_soft=fail_soft)
    if fd is None:
        return 0
    try:
        set_brightness(fd, 40 if sequence[-1][0] == "sleep" else 100)
        for i, (workflow_id, theme_id) in enumerate(sequence):
            face = faces[(workflow_id, theme_id, ticker)]
            print(f"push {workflow_id} · {theme_id}")
            if workflow_id == "sleep":
                set_brightness(fd, 35)
            else:
                set_brightness(fd, 100)
            push_face(fd, face)
            if hold and i < len(sequence) - 1:
                time.sleep(hold)
        last_w, last_t = sequence[-1]
        remember = {"face": last_w, "theme": last_t}
        if ticker:
            remember["ticker"] = ticker
            remember["intent"] = ticker
        save_occupancy(**remember)
        print(f"left {last_w} · {last_t} on the Plus")
    finally:
        os.close(fd)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
