#!/usr/bin/python3
"""Minimal test LSP/tool: logs requests; never invokes a real compiler."""
import json
import os
import sys

name = os.path.basename(sys.argv[0])
log = os.environ["NVIM_TEST_EVENTS"]


def record(value):
    with open(log, "a") as stream:
        stream.write(json.dumps(value) + "\n")


record({"process": name, "path": sys.argv[0], "args": sys.argv[1:]})
if name == "go":
    print("/tmp/nvim-test-go")
    sys.exit(0)
if name == "cargo":
    if "metadata" in sys.argv:
        print(json.dumps({"workspace_root": os.environ["NVIM_TEST_PROJECT"]}))
    else:
        print("fake Cargo: " + " ".join(sys.argv[1:]))
    sys.exit(0)

while True:
    headers = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            sys.exit(0)
        if line in (b"\r\n", b"\n"):
            break
        key, value = line.decode().split(":", 1)
        headers[key.lower()] = value.strip()
    message = json.loads(sys.stdin.buffer.read(int(headers["content-length"])))
    record({"server": name, "message": message})
    method = message.get("method")
    if method == "exit":
        sys.exit(0)
    if "id" not in message:
        continue
    result = None
    if method == "initialize":
        result = {
            "capabilities": {
                "textDocumentSync": 1,
                "hoverProvider": True,
                "documentFormattingProvider": True,
                "documentRangeFormattingProvider": True,
                "inlayHintProvider": True,
                "signatureHelpProvider": {"triggerCharacters": ["("]},
            }
        }
    elif method in ("textDocument/formatting", "textDocument/rangeFormatting"):
        result = []
    response = json.dumps(
        {"jsonrpc": "2.0", "id": message["id"], "result": result}
    ).encode()
    sys.stdout.buffer.write(
        b"Content-Length: " + str(len(response)).encode() + b"\r\n\r\n" + response
    )
    sys.stdout.buffer.flush()
