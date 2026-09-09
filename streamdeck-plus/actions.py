#!/usr/bin/env python3
"""Real Stream Deck Plus actions. Complementary to Omarchy. Not a catalog."""

from __future__ import annotations

import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

ROOT = Path("/home/jordan/.local/share/omarchy-streamdeck-demo")
JOB = ROOT / "jobs" / "say-the-job"
JOB_JSON = JOB / "job.json"
THEME_ROOT = Path("/home/jordan/.config/omarchy/themes")
DISPATCH_SH = Path.home() / ".grok/skills/local-worker/scripts/dispatch.sh"
PLUS_CHROME = ("jordan-os", "jordan-xp", "skull", "mudhawk", "the-shit")
# Four pages. Swipe and PAGE cycle this order. sleep is lock, not a page.
FACE_ORDER = ("music", "desk", "space", "crew")


@dataclass
class ActionResult:
    ok: bool
    message: str
    face: str | None = None
    ticker: str | None = None
    paint: bool = False
    lock_after: bool = False
    mood: str | None = None
    recording: bool | None = None


def _run(
    argv: list[str],
    *,
    dry_run: bool,
    timeout: int = 12,
    spawn: bool = False,
) -> ActionResult:
    shown = " ".join(argv)
    if dry_run:
        kind = "spawn" if spawn else "run"
        return ActionResult(True, f"dry-run {kind}: {shown}")
    try:
        if spawn:
            subprocess.Popen(
                argv,
                start_new_session=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            return ActionResult(True, shown)
        proc = subprocess.run(
            argv,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except FileNotFoundError:
        return ActionResult(False, f"missing: {argv[0]}")
    except subprocess.TimeoutExpired:
        return ActionResult(False, f"timeout: {shown}")
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip().splitlines()
        tail = err[-1] if err else f"exit {proc.returncode}"
        return ActionResult(False, f"{shown}: {tail}")
    out = (proc.stdout or "").strip()
    return ActionResult(True, out or shown)


def notify(headline: str, body: str = "", *, dry_run: bool = False) -> None:
    argv = [
        "omarchy",
        "notification",
        "send",
        "--app-name",
        "Stream Deck",
        "-g",
        "",
        headline,
    ]
    if body:
        argv.append(body[:180])
    _run(argv, dry_run=dry_run, timeout=4)


def read_volume() -> tuple[float, bool]:
    try:
        out = subprocess.check_output(
            ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"],
            text=True,
            timeout=1,
        )
    except (FileNotFoundError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
        return 0.0, False
    muted = "MUTED" in out.upper()
    vol = 0.0
    for tok in out.replace("[MUTED]", "").split():
        try:
            vol = float(tok)
            break
        except ValueError:
            continue
    return max(0.0, min(vol, 1.5)), muted


def fleet_line() -> str:
    host = os.uname().nodename.split(".")[0]
    try:
        load = open("/proc/loadavg", encoding="utf-8").read().split()[0]
    except OSError:
        load = "?"
    try:
        info = open("/proc/meminfo", encoding="utf-8").read().splitlines()
        nums = {}
        for line in info:
            if line.startswith(("MemTotal:", "MemAvailable:")):
                key, val, *_ = line.replace(":", "").split()
                nums[key] = int(val)
        total = nums.get("MemTotal") or 1
        avail = nums.get("MemAvailable") or 0
        used = max(0, 100 - int(avail * 100 / total))
        ram = f"{used}%"
    except (OSError, ValueError):
        ram = "?"
    return f"{host} · load {load} · {ram} ram"


def theme_pack_exists(slug: str) -> bool:
    return (THEME_ROOT / slug).is_dir()


def next_theme_slug(current: str) -> str | None:
    order = [s for s in PLUS_CHROME if theme_pack_exists(s)]
    if not order:
        return None
    cur = current if current in order else order[0]
    return order[(order.index(cur) + 1) % len(order)]


def normalize_face(current: str) -> str:
    if current in ("listen", "dispatch"):
        return "crew"
    if current in FACE_ORDER or current == "sleep":
        return current
    return "crew"


def cycle_face(current: str, delta: int) -> str:
    cur = normalize_face(current)
    if cur not in FACE_ORDER:
        cur = "crew"
    idx = FACE_ORDER.index(cur)
    return FACE_ORDER[(idx + int(delta)) % len(FACE_ORDER)]


def page_dots(workflow_id: str) -> str:
    wid = normalize_face(workflow_id)
    if wid not in FACE_ORDER:
        return ""
    i = FACE_ORDER.index(wid)
    return "  ".join("●" if j == i else "○" for j in range(len(FACE_ORDER)))


def _hypr_env() -> dict[str, str]:
    env = os.environ.copy()
    runtime = Path(env.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}")
    if not env.get("HYPRLAND_INSTANCE_SIGNATURE"):
        hypr = runtime / "hypr"
        if hypr.is_dir():
            kids = sorted(p.name for p in hypr.iterdir() if p.is_dir())
            if kids:
                env["HYPRLAND_INSTANCE_SIGNATURE"] = kids[0]
    if not env.get("WAYLAND_DISPLAY"):
        for name in ("wayland-1", "wayland-0"):
            if (runtime / name).exists():
                env["WAYLAND_DISPLAY"] = name
                break
    return env


def spotify_is_playing() -> bool:
    try:
        raw = subprocess.check_output(
            ["spotify", "current", "--json"],
            text=True,
            timeout=3,
        )
        data = json.loads(raw)
    except (FileNotFoundError, subprocess.CalledProcessError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return False
    return bool(isinstance(data, dict) and data.get("is_playing"))


def nightlight_on() -> bool:
    try:
        raw = subprocess.check_output(
            ["omarchy", "toggle", "nightlight", "--status"],
            text=True,
            timeout=2,
        )
        data = json.loads(raw)
    except (FileNotFoundError, subprocess.CalledProcessError, subprocess.TimeoutExpired, json.JSONDecodeError):
        return False
    return bool(isinstance(data, dict) and data.get("enabled"))


def job_is_dispatchable() -> tuple[bool, str]:
    if not JOB_JSON.is_file():
        return False, "no job.json"
    try:
        data = json.loads(JOB_JSON.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False, "job.json unreadable"
    if not isinstance(data, dict):
        return False, "job.json not an object"
    repo = Path(str(data.get("repo") or ""))
    model = str(data.get("model") or "")
    if "qwen3-coder-next" in model:
        return False, "wrong model"
    if not repo.is_dir():
        return False, "job repo missing"
    if not (repo / ".git").exists():
        return False, "job repo is not git; occupancy only"
    if not DISPATCH_SH.is_file():
        return False, "dispatch.sh missing"
    return True, str(JOB_JSON)


def action_for_key(face: str, title: str) -> str | None:
    title = (title or "").strip().upper()
    if not title:
        return None
    face = normalize_face(face) if face != "sleep" else face
    shared = {
        "PAGE": "face_next",
        "SHOT": "shot",
        "LOCK": "lock" if face != "sleep" else "wake_crew",
        "LOCAL": "local_dispatch",
        "NIGHT": "night_status",
    }
    by_face = {
        "crew": {
            "GROK": "spec_capture",
            "SPEC": "spec_capture",
            **shared,
        },
        "listen": {
            "GROK": "spec_capture",
            "SPEC": "spec_capture",
            **shared,
        },
        "desk": {
            "MUTE": "mute",
            "SHOT": "shot",
            "REC": "rec_toggle",
            "NITE": "nightlight_toggle",
            "DND": "dnd_toggle",
            "THEME": "theme_cycle",
            "BG": "bg_next",
            **shared,
        },
        "music": {
            "CHILL": "mood_chill",
            "FLOW": "mood_flow",
            "HYPE": "mood_hype",
            "SKIP": "skip",
            "PLAY": "play_toggle",
            "LIKE": "like_none",
            **shared,
        },
        "space": {
            "WS-": "ws_prev",
            "WS+": "ws_next",
            "WEB": "launch_browser",
            "TERM": "launch_terminal",
            "HERDR": "launch_herdr",
            **shared,
        },
        "sleep": {
            "LOCK": "wake_crew",
        },
    }
    return by_face.get(face, shared).get(title)


def encoder_action(index: int, *, ticks: int = 0, pressed: bool = False) -> str | None:
    if index == 0:
        if pressed:
            return "mute"
        if ticks > 0:
            return "vol_up"
        if ticks < 0:
            return "vol_down"
    elif index == 1:
        if pressed:
            return "mic"
    elif index == 2:
        if pressed:
            return "bright_toggle"
        if ticks > 0:
            return "bright_up"
        if ticks < 0:
            return "bright_down"
    elif index == 3:
        if pressed:
            return "play_toggle"
        if ticks > 0:
            return "skip"
        if ticks < 0:
            return "skip_prev"
    return None


def workspace_focus(delta: int, *, dry_run: bool) -> ActionResult:
    env = _hypr_env()
    try:
        raw_ws = subprocess.check_output(
            ["hyprctl", "-j", "workspaces"], env=env, timeout=2
        )
        raw_act = subprocess.check_output(
            ["hyprctl", "-j", "activeworkspace"], env=env, timeout=2
        )
        workspaces = json.loads(raw_ws)
        active = json.loads(raw_act)
    except (FileNotFoundError, subprocess.CalledProcessError, subprocess.TimeoutExpired, json.JSONDecodeError) as exc:
        return ActionResult(False, f"hyprctl: {exc}")
    if not isinstance(workspaces, list) or not isinstance(active, dict):
        return ActionResult(False, "hyprctl: bad json")
    monitor = active.get("monitor")
    try:
        cur = int(active.get("id"))
    except (TypeError, ValueError):
        return ActionResult(False, "hyprctl: no active workspace")
    ids: list[int] = []
    for item in workspaces:
        if not isinstance(item, dict):
            continue
        if item.get("monitor") != monitor:
            continue
        try:
            wid = int(item.get("id"))
            wins = int(item.get("windows") or 0)
        except (TypeError, ValueError):
            continue
        if wid > 0 and wins > 0:
            ids.append(wid)
    ids = sorted(set(ids))
    if cur not in ids:
        ids = sorted(set(ids + [cur]))
    if not ids:
        return ActionResult(False, "no occupied workspaces")
    nxt = ids[(ids.index(cur) + int(delta)) % len(ids)]
    if dry_run:
        return ActionResult(True, f"dry-run workspace {nxt}")
    lua = (
        "hl.dispatch(hl.dsp.focus({ workspace = %d, on_current_monitor = true }))"
        % nxt
    )
    try:
        proc = subprocess.run(
            ["hyprctl", "eval", lua],
            env=env,
            capture_output=True,
            text=True,
            timeout=2,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired) as exc:
        return ActionResult(False, f"hyprctl eval: {exc}")
    if proc.returncode != 0:
        err = (proc.stderr or proc.stdout or "").strip().splitlines()
        return ActionResult(False, err[-1] if err else f"workspace {nxt} failed")
    return ActionResult(True, f"workspace {nxt}")


def perform(
    name: str,
    *,
    dry_run: bool = False,
    write_intent=None,
    current_theme: str = "jordan-os",
    recording: bool = False,
    night_ready: bool = False,
) -> ActionResult:
    if name == "face_listen":
        return ActionResult(True, "face crew", face="crew", paint=True)
    if name == "face_crew":
        return ActionResult(True, "face crew", face="crew", paint=True)
    if name == "face_music":
        return ActionResult(True, "face music", face="music", paint=True)
    if name == "face_desk":
        return ActionResult(True, "face desk", face="desk", paint=True)
    if name == "face_space":
        return ActionResult(True, "face space", face="space", paint=True)
    if name == "face_next":
        # Caller paints via occupancy; we return the next face name.
        return ActionResult(True, "page +1", paint=True)
    if name == "wake_crew":
        r = _run(["omarchy", "system", "wake"], dry_run=dry_run, timeout=6)
        r.face = "crew"
        r.paint = True
        r.message = "wake → crew" if r.ok else r.message
        return r
    if name == "lock":
        notify("LOCK", "sleep face, then omarchy system lock", dry_run=dry_run)
        r = ActionResult(True, "lock", face="sleep", paint=True, lock_after=True)
        if dry_run:
            r.message = "dry-run: paint sleep + omarchy system lock"
        return r
    if name == "shot":
        r = _run(
            ["omarchy", "capture", "screenshot", "fullscreen", "save"],
            dry_run=dry_run,
            timeout=20,
        )
        if r.ok and not dry_run:
            r.message = "screenshot saved"
            notify("SHOT", r.message, dry_run=False)
        return r
    if name == "rec_toggle":
        if recording:
            r = _run(
                ["omarchy", "capture", "screenrecording", "--stop-recording"],
                dry_run=dry_run,
                timeout=20,
            )
            r.recording = False
            r.paint = True
            r.message = "record stop" if r.ok else r.message
            return r
        r = _run(
            ["omarchy", "capture", "screenrecording", "--fullscreen"],
            dry_run=dry_run,
            spawn=True,
        )
        r.recording = True
        r.paint = True
        r.message = "record start" if r.ok else r.message
        return r
    if name == "mute":
        r = _run(
            ["omarchy", "audio", "output", "volume", "mute-toggle"],
            dry_run=dry_run,
            timeout=6,
        )
        r.paint = True
        return r
    if name == "mic":
        r = _run(["omarchy", "audio", "input", "mute"], dry_run=dry_run, timeout=6)
        r.paint = True
        return r
    if name == "vol_up":
        return _run(
            ["omarchy", "audio", "output", "volume", "raise"],
            dry_run=dry_run,
            timeout=6,
        )
    if name == "vol_down":
        return _run(
            ["omarchy", "audio", "output", "volume", "lower"],
            dry_run=dry_run,
            timeout=6,
        )
    if name == "bright_up":
        return _run(
            ["omarchy", "brightness", "display", "+5%"],
            dry_run=dry_run,
            timeout=6,
        )
    if name == "bright_down":
        return _run(
            ["omarchy", "brightness", "display", "5%-"],
            dry_run=dry_run,
            timeout=6,
        )
    if name == "bright_toggle":
        return _run(
            ["omarchy", "brightness", "display", "off"],
            dry_run=dry_run,
            timeout=6,
        )
    if name == "skip":
        return _run(["spotify", "skip", "next"], dry_run=dry_run, spawn=True)
    if name == "skip_prev":
        return _run(["spotify", "skip", "prev"], dry_run=dry_run, spawn=True)
    if name in ("pause", "play", "play_toggle"):
        if name == "pause" or (name == "play_toggle" and spotify_is_playing()):
            r = _run(["spotify", "pause"], dry_run=dry_run, spawn=True)
            r.message = "pause" if r.ok else r.message
        else:
            r = _run(["spotify", "resume"], dry_run=dry_run, spawn=True)
            r.message = "play" if r.ok else r.message
        r.paint = True
        r.face = "music"
        return r
    if name == "nightlight_toggle":
        r = _run(["omarchy", "toggle", "nightlight"], dry_run=dry_run, timeout=6)
        r.paint = True
        r.face = "desk"
        return r
    if name == "dnd_toggle":
        r = _run(
            ["omarchy", "toggle", "notification", "silencing"],
            dry_run=dry_run,
            timeout=6,
        )
        r.paint = True
        r.face = "desk"
        return r
    if name == "bg_next":
        r = _run(["omarchy", "theme", "bg", "next"], dry_run=dry_run, timeout=8)
        r.paint = True
        return r
    if name == "launch_browser":
        return _run(["omarchy", "launch", "browser"], dry_run=dry_run, spawn=True)
    if name == "launch_terminal":
        return _run(["omarchy", "launch", "terminal"], dry_run=dry_run, spawn=True)
    if name == "launch_herdr":
        return _run(["omarchy", "launch", "terminal", "herdr"], dry_run=dry_run, spawn=True)
    if name in ("ws_next", "ws_prev"):
        return workspace_focus(1 if name == "ws_next" else -1, dry_run=dry_run)
    if name in ("mood_chill", "mood_flow", "mood_hype"):
        mood = name.split("_", 1)[1]
        r = _run(["spotify", mood], dry_run=dry_run, spawn=True)
        r.face = "music"
        r.paint = True
        r.mood = mood
        r.ticker = mood.upper()
        if r.ok:
            notify("MUSIC", f"queue {mood}", dry_run=dry_run)
        return r
    if name == "like_none":
        msg = "no like door — the-shit/music has no save command"
        notify("LIKE", msg, dry_run=dry_run)
        return ActionResult(True, msg)
    if name == "theme_cycle":
        nxt = next_theme_slug(current_theme)
        if not nxt:
            return ActionResult(False, "no Plus chrome themes")
        r = _run(["omarchy", "theme", "set", nxt], dry_run=dry_run, timeout=25)
        r.paint = True
        if r.ok:
            r.message = f"theme {nxt}"
        return r
    if name == "fleet_brief":
        line = fleet_line()
        notify("FLEET", line, dry_run=dry_run)
        return ActionResult(True, line, ticker=line, paint=True)
    if name == "night_status":
        line = "NIGHT queue" if night_ready else "NIGHT idle — not night-ready"
        notify("NIGHT", line, dry_run=dry_run)
        return ActionResult(True, line, ticker=line, paint=True)
    if name == "local_dispatch":
        ok, why = job_is_dispatchable()
        if not ok:
            notify("LOCAL", why, dry_run=dry_run)
            return ActionResult(True, why, face="crew", paint=True)
        r = _run([str(DISPATCH_SH), why], dry_run=dry_run, spawn=True)
        r.face = "crew"
        r.paint = True
        if r.ok:
            r.message = "LOCAL dispatch.sh spawned — no merge"
            notify("LOCAL", "qwen dispatched", dry_run=dry_run)
        return r
    if name == "spec_capture":
        if dry_run:
            return ActionResult(
                True,
                "dry-run: omarchy menu input SAY THE JOB → occupancy",
                face="crew",
                paint=True,
            )
        try:
            proc = subprocess.run(
                ["omarchy", "menu", "input", "SAY THE JOB"],
                capture_output=True,
                text=True,
                timeout=180,
            )
        except subprocess.TimeoutExpired:
            return ActionResult(False, "SPEC input timeout", face="crew")
        except FileNotFoundError:
            return ActionResult(False, "missing omarchy menu", face="crew")
        sentence = " ".join((proc.stdout or "").split())
        if proc.returncode != 0 or not sentence:
            return ActionResult(False, "SPEC cancelled", face="crew")
        if write_intent:
            write_intent(sentence)
        notify("SPEC", sentence, dry_run=False)
        return ActionResult(
            True,
            f"occupancy ← {sentence}",
            face="crew",
            ticker=sentence,
            paint=True,
        )
    return ActionResult(False, f"unknown action {name}")
