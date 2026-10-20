"""Local bridge between this repo and Roblox Studio for the asset pipeline.

Rojo is the normal way to sync code (see README). This server exists for the
parts Rojo can't do: moving Blender meshes into Studio and saving the prefabs
Studio builds back into the repo as .rbxm files.

Studio talks to it with HttpService, so HttpService.HttpEnabled must be on in
the place while you use it (turn it off again when you're done).

    python tools/pipeline/dev_server.py        # http://127.0.0.1:8765

Endpoints
    GET  /<repo path>            raw file (only build/, assets/, src/, tools/pipeline/, tools/studio/)
    GET  /b64?path=<repo path>   file contents as base64 (for binary .rbxm)
    GET  /rojo-tree.json         default.project.json expanded into an instance tree
    POST /save?path=<repo path>[&b64=1]   write a file (only assets/ and build/)
"""

import base64
import json
import os
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PORT = int(os.environ.get("MM_DEV_PORT", "8765"))
READABLE = ("build/", "assets/", "src/", "tools/pipeline/", "tools/studio/")
WRITABLE = ("assets/models/", "assets/meshes/", "build/")
SCRIPT_EXTS = (".luau", ".lua")


def _safe(rel, allowed):
    rel = rel.replace("\\", "/").lstrip("/")
    return rel if ".." not in rel.split("/") and rel.startswith(allowed) else None


def _script_class(filename):
    stem, ext = os.path.splitext(filename)
    if ext not in SCRIPT_EXTS:
        return None, None
    if stem.endswith(".server"):
        return stem[: -len(".server")], "Script"
    if stem.endswith(".client"):
        return stem[: -len(".client")], "LocalScript"
    return stem, "ModuleScript"


def _read(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def _from_path(name, rel):
    """Mirror Rojo's file -> instance rules for the file types this repo uses."""
    full = os.path.join(ROOT, rel)
    if os.path.isdir(full):
        node = {"name": name, "className": "Folder", "children": []}
        entries = sorted(os.listdir(full))
        for entry in entries:
            if entry.startswith("init.") and entry.endswith(SCRIPT_EXTS):
                _, cls = _script_class(entry)
                node["className"] = cls
                node["source"] = _read(os.path.join(full, entry))
        for entry in entries:
            if entry.startswith("init.") or entry.startswith("."):
                continue
            child_rel = rel.rstrip("/") + "/" + entry
            child_name, _ = _script_class(entry)
            if os.path.isdir(os.path.join(full, entry)):
                node["children"].append(_from_path(entry, child_rel))
            elif entry.endswith((".rbxm", ".rbxmx")):
                node["children"].append({"name": os.path.splitext(entry)[0], "rbxm": child_rel})
            elif child_name:
                node["children"].append(_from_path(child_name, child_rel))
        return node
    if rel.endswith((".rbxm", ".rbxmx")):
        return {"name": name, "rbxm": rel}
    _, cls = _script_class(os.path.basename(rel))
    return {"name": name, "className": cls, "source": _read(full)}


def _expand(name, desc):
    node = {"name": name, "children": []}
    if "$path" in desc:
        rel = desc["$path"]
        if os.path.exists(os.path.join(ROOT, rel)):
            node = _from_path(name, rel)
        else:
            node["missing"] = rel
    if "$className" in desc:
        node["className"] = desc["$className"]
    if "$properties" in desc:
        node["properties"] = desc["$properties"]
    node.setdefault("children", [])
    for key, value in desc.items():
        if not key.startswith("$") and isinstance(value, dict):
            node["children"].append(_expand(key, value))
    return node


def rojo_tree():
    with open(os.path.join(ROOT, "default.project.json"), "r", encoding="utf-8") as f:
        project = json.load(f)
    return _expand("game", project["tree"])


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def _reply(self, status, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else body.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        url = urlparse(self.path)
        rel = url.path.lstrip("/")
        if rel == "rojo-tree.json":
            return self._reply(200, json.dumps(rojo_tree()))
        if rel == "b64":
            target = _safe(parse_qs(url.query).get("path", [""])[0], READABLE)
            if not target or not os.path.isfile(os.path.join(ROOT, target)):
                return self._reply(404, '{"error":"not found"}')
            with open(os.path.join(ROOT, target), "rb") as f:
                return self._reply(200, base64.b64encode(f.read()), "text/plain")
        if not _safe(rel, READABLE):
            return self._reply(403, '{"error":"forbidden"}')
        return super().do_GET()

    def do_POST(self):
        url = urlparse(self.path)
        query = parse_qs(url.query)
        target = _safe(query.get("path", [""])[0], WRITABLE)
        if url.path != "/save" or not target:
            return self._reply(403, '{"error":"forbidden"}')
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        if query.get("b64", ["0"])[0] == "1":
            body = base64.b64decode(body)
        dest = os.path.join(ROOT, target)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as f:
            f.write(body)
        print(f"saved {target} ({len(body)} bytes)", flush=True)
        return self._reply(200, '{"ok":true}')

    def log_message(self, fmt, *args):
        pass


if __name__ == "__main__":
    print(f"Math Money dev server on http://127.0.0.1:{PORT} (repo: {ROOT})", flush=True)
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
