#!/usr/bin/env python3
"""
ytmd-nowplaying.py
Reads now-playing + queue from a running Venipa ytmdesktop2 (YouTube Music for Desktop)
via Chromium's remote debugging protocol. No app rebuild, no built-in HTTP API needed.

SETUP
  1. sudo pacman -S python-websocket-client python-requests
  2. Launch the app with the debug port AND origin flag:
       ytmdesktop --remote-debugging-port=9222 --remote-allow-origins=*
  3. python ytmd-nowplaying.py

OUTPUT
  Writes ~/.cache/ytmd-now.json every second and prints one compact JSON line to stdout.

The queue is read from YTM's internal Redux store (the source of truth the app itself
uses), NOT scraped from the DOM, so it stays in sync with the player and has no
song/video counterpart duplicates. If the store path ever breaks, it falls back to a
de-duplicated DOM scrape and tags the result with "queueSource" so you can tell which ran.
"""

import json
import os
import sys
import time
import requests
import websocket  # websocket-client

DEBUG_HOST = "127.0.0.1"
DEBUG_PORT = 9222
OUT_FILE = os.path.expanduser("~/.cache/ytmd-now.json")
POLL_SECONDS = 1.0

PAGE_EXPR = r"""
(() => {
  const text = (o) => (o && o.runs && o.runs.map(x => x.text).join("")) || null;
  // YTM art URLs end in a size suffix (=w60-h60-... or =s60-...). Rewrite it to request a bigger render.
  const upscale = (url, size) => {
    if (!url) return url;
    if (/=w\d+-h\d+/.test(url)) return url.replace(/=w\d+-h\d+/, "=w" + size + "-h" + size);
    if (/=s\d+/.test(url)) return url.replace(/=s\d+/, "=s" + size);
    return url;
  };

  function fromStore(app, curId) {
    // YTM keeps the live queue in its Redux store. Try the known paths defensively.
    let state = null;
    try { state = app.store.getState(); } catch (e) {}
    if (!state) return null;
    const q = state.queue || {};
    const raw = [].concat(q.items || [], q.automixItems || []);
    if (!raw.length) return null;

    const norm = raw.map(it => {
      // Items can be wrapped (song/video counterpart). Always take the primary renderer.
      const w = it.playlistPanelVideoWrapperRenderer;
      const rend = w
        ? (w.primaryRenderer && w.primaryRenderer.playlistPanelVideoRenderer)
        : it.playlistPanelVideoRenderer;
      if (!rend) return null;
      const qThumbs = (rend.thumbnail && rend.thumbnail.thumbnails) || [];
      return {
        videoId: rend.videoId || null,
        title: text(rend.title),
        artist: text(rend.shortBylineText) || text(rend.longBylineText),
        duration: rend.lengthText ? text(rend.lengthText) : null,
        art: qThumbs.length ? upscale(qThumbs[qThumbs.length - 1].url, 544) : null,
        selected: !!rend.selected,
      };
    }).filter(Boolean);

    if (!norm.length) return null;

    let curIdx = curId ? norm.findIndex(i => i.videoId && i.videoId === curId) : -1;
    if (curIdx === -1) curIdx = norm.findIndex(i => i.selected);

    const before = 3, after = 3;
    const start = curIdx === -1 ? 0 : Math.max(0, curIdx - before);
    const slice = curIdx === -1 ? norm : norm.slice(start, curIdx + after + 1);
    return slice.map((i, idx) => ({
      title: i.title,
      artist: i.artist,
      duration: i.duration,
      art: i.art,
      playing: curIdx !== -1 && (start + idx) === curIdx,
      offset: curIdx === -1 ? null : (start + idx) - curIdx,
    }));
  }

  function fromDom(curTitle) {
    // Fallback: scrape DOM, drop nested counterparts, collapse consecutive same-title dupes.
    let items = Array.from(document.querySelectorAll("ytmusic-player-queue-item"))
      .filter(el => !el.parentElement.closest("ytmusic-player-queue-item"))
      .map(el => {
        const q = (sel) => { const n = el.querySelector(sel); return n ? n.textContent.trim() : null; };
        const img = el.querySelector("img");
        return {
          title: q(".song-title") || q("yt-formatted-string.song-title"),
          artist: q(".byline") || q("yt-formatted-string.byline"),
          duration: q(".duration"),
          art: img ? upscale(img.src, 544) : null,
        };
      });
    // collapse consecutive duplicates (handles counterpart siblings + double containers)
    items = items.filter((it, i) => i === 0 || it.title !== items[i - 1].title);

    let curIdx = curTitle ? items.findIndex(i => i.title === curTitle) : -1;
    const before = 3, after = 3;
    const start = curIdx === -1 ? 0 : Math.max(0, curIdx - before);
    const slice = curIdx === -1 ? items : items.slice(start, curIdx + after + 1);
    return slice.map((i, idx) => ({
      title: i.title,
      artist: i.artist,
      duration: i.duration,
      art: i.art,
      playing: curIdx !== -1 && (start + idx) === curIdx,
      offset: curIdx === -1 ? null : (start + idx) - curIdx,
    }));
  }

  try {
    const app = document.querySelector("body>ytmusic-app");
    const p = app && app.playerApi;
    if (!p || !p.getPlayerResponse) return JSON.stringify({ available: false });

    const r = p.getPlayerResponse() || {};
    const vd = r.videoDetails || {};
    const thumbs = (vd.thumbnail && vd.thumbnail.thumbnails) || [];
    const state = p.getPlayerState ? p.getPlayerState() : -1;
    const curId = vd.videoId || null;

    let queue = null, source = "store";
    try { queue = fromStore(app, curId); } catch (e) { queue = null; }
    if (!queue || !queue.length) { source = "dom"; try { queue = fromDom(vd.title || null); } catch (e) { queue = []; } }

    return JSON.stringify({
      available: true,
      playing: state === 1,
      state,
      title: vd.title || null,
      artist: vd.author || null,
      videoId: curId,
      durationSeconds: vd.lengthSeconds ? Number(vd.lengthSeconds) : (p.getDuration ? p.getDuration() : null),
      progressSeconds: p.getCurrentTime ? p.getCurrentTime() : null,
      art: thumbs.length ? thumbs[thumbs.length - 1].url : null,
      thumbnails: thumbs.length > 1 ? [thumbs[0], thumbs[thumbs.length - 1]] : thumbs,
      queueSource: source,
      queue: queue || [],
    });
  } catch (e) {
    return JSON.stringify({ available: false, error: String(e) });
  }
})()
"""


def find_ytm_target():
    url = f"http://{DEBUG_HOST}:{DEBUG_PORT}/json"
    targets = requests.get(url, timeout=3).json()
    for t in targets:
        if t.get("type") == "page" and "music.youtube.com" in (t.get("url") or ""):
            return t["webSocketDebuggerUrl"]
    for t in targets:
        if t.get("type") == "page":
            return t["webSocketDebuggerUrl"]
    return None


def evaluate(ws, msg_id, expression):
    ws.send(json.dumps({
        "id": msg_id,
        "method": "Runtime.evaluate",
        "params": {"expression": expression, "returnByValue": True, "awaitPromise": True},
    }))
    while True:
        data = json.loads(ws.recv())
        if data.get("id") == msg_id:
            return data


def connect():
    ws_url = find_ytm_target()
    if not ws_url:
        raise RuntimeError("No YouTube Music page found among debug targets.")
    ws = websocket.create_connection(ws_url, timeout=5)
    ws.send(json.dumps({"id": 1, "method": "Runtime.enable"}))
    return ws


def main():
    try:
        ws = connect()
    except Exception as e:
        print(f"Cannot connect: {e}", file=sys.stderr)
        print("Launch with: ytmdesktop --remote-debugging-port=9222 --remote-allow-origins=*", file=sys.stderr)
        sys.exit(1)

    msg_id = 2
    os.makedirs(os.path.dirname(OUT_FILE), exist_ok=True)

    while True:
        try:
            resp = evaluate(ws, msg_id, PAGE_EXPR)
            msg_id += 1
            value = resp.get("result", {}).get("result", {}).get("value")
            payload = json.loads(value) if value else {"available": False}
        except Exception as e:
            payload = {"available": False, "error": str(e)}
            try: ws.close()
            except Exception: pass
            try:
                ws = connect(); msg_id = 2
            except Exception:
                time.sleep(2)

        line = json.dumps(payload, ensure_ascii=False)
        try:
            with open(OUT_FILE, "w", encoding="utf-8") as f:
                f.write(line)
        except Exception as e:
            print(f"write failed: {e}", file=sys.stderr)
        print(line, flush=True)
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
