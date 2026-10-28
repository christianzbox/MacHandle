#!/usr/bin/env python3
"""Synthetic subprocess contract tests. No SDK install, app configuration or personal data."""
import argparse
import json
import os
import select
import signal
import subprocess
import time
import unittest

EXECUTABLE = None
META = {"io.modelcontextprotocol/protocolVersion": "2026-07-28",
        "io.modelcontextprotocol/clientCapabilities": {}}


def request(method, identifier=1, params=None, modern=True):
    values = dict(params or {})
    if modern:
        values["_meta"] = META
    message = {"jsonrpc": "2.0", "method": method, "params": values}
    if identifier is not None:
        message["id"] = identifier
    return json.dumps(message, separators=(",", ":")).encode() + b"\n"


class Helper:
    def __init__(self, args=None):
        self.process = subprocess.Popen([EXECUTABLE] + (args if args is not None else ["--synthetic"]),
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, bufsize=0)
        self.buffer = b""

    def send(self, data):
        offset = 0
        while offset < len(data):
            offset += os.write(self.process.stdin.fileno(), data[offset:])

    def receive(self, timeout=3):
        deadline = time.monotonic() + timeout
        while b"\n" not in self.buffer:
            remaining = deadline - time.monotonic()
            if remaining <= 0 or not select.select([self.process.stdout], [], [], remaining)[0]:
                raise AssertionError("No bounded protocol response")
            chunk = os.read(self.process.stdout.fileno(), 4096)
            if not chunk:
                raise AssertionError("Unexpected helper EOF")
            self.buffer += chunk
        line, self.buffer = self.buffer.split(b"\n", 1)
        return json.loads(line)

    def close(self):
        if self.process.stdin and not self.process.stdin.closed:
            self.process.stdin.close()
        try:
            self.process.wait(timeout=4)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=2)
            raise AssertionError("Helper did not stop within four seconds")
        finally:
            for pipe in [self.process.stdout, self.process.stderr]:
                if pipe and not pipe.closed:
                    pipe.close()


class StdioTests(unittest.TestCase):
    def setUp(self):
        self.helper = Helper()
        self.addCleanup(self.helper.close)

    def test_modern_discovery_schema_and_tools(self):
        h = self.helper
        wire = request("server/discover")
        for part in [wire[:3], wire[3:20], wire[20:]]:
            h.send(part)
        result = h.receive()["result"]
        self.assertIn("2026-07-28", result["supportedVersions"])
        self.assertEqual(result["resultType"], "complete")
        h.send(request("tools/list", 2))
        tools = h.receive()["result"]["tools"]
        self.assertEqual([t["name"] for t in tools], ["mock_add", "mock_fail", "mock_status", "mock_wait"])
        self.assertFalse(tools[0]["inputSchema"]["additionalProperties"])
        h.send(request("tools/call", 3, {"name": "mock_add", "arguments": {"a": 20, "b": 22}}))
        self.assertEqual(h.receive()["result"]["structuredContent"], {"sum": 42})
        h.send(request("tools/call", 4, {"name": "mock_fail"}))
        self.assertTrue(h.receive()["result"]["isError"])
        h.process.stdin.close()
        self.assertEqual(h.process.wait(timeout=3), 0)
        self.assertEqual(h.process.stderr.read(), b"")

    def test_legacy_lifecycle_and_clean_restart(self):
        for iteration in range(2):
            h = self.helper if iteration == 0 else Helper()
            if iteration:
                self.addCleanup(h.close)
            h.send(request("initialize", 1, {"protocolVersion": "2025-11-25", "capabilities": {},
                                             "clientInfo": {"name": "Synthetic", "version": "1"}}, False))
            self.assertEqual(h.receive()["result"]["protocolVersion"], "2025-11-25")
            h.send(request("notifications/initialized", None, modern=False))
            h.send(request("tools/list", 2, modern=False))
            self.assertEqual(len(h.receive()["result"]["tools"]), 4)
            h.close()

    def test_cancellation_does_not_emit_late_result(self):
        h = self.helper
        h.send(request("tools/call", 1, {"name": "mock_wait", "arguments": {"milliseconds": 1000}}))
        h.send(request("notifications/cancelled", None, {"requestId": 1}))
        h.send(request("ping", 2))
        self.assertEqual(h.receive()["id"], 2)
        self.assertFalse(h.buffer)
        self.assertFalse(select.select([h.process.stdout], [], [], 1.2)[0])
        h.send(request("tools/call", 3, {"name": "mock_status"}))
        self.assertEqual(h.receive()["id"], 3)

    def test_malformed_frame_recovers_without_echoing_input(self):
        h = self.helper
        h.send(b'{"synthetic-private-marker":\xff}\n')
        result = h.receive()
        self.assertEqual(result["error"]["code"], -32700)
        self.assertNotIn("synthetic-private-marker", json.dumps(result))
        h.send(request("ping", 1))
        self.assertIn("result", h.receive())

    def test_frame_limit_and_partial_eof_are_fatal(self):
        h = self.helper
        h.send(b" " * 65537)
        self.assertEqual(h.process.wait(timeout=3), 1)
        other = Helper()
        self.addCleanup(other.close)
        other.send(b'{"partial":')
        other.process.stdin.close()
        self.assertEqual(other.process.wait(timeout=3), 1)

    def test_eof_cancels_pending_work(self):
        h = self.helper
        h.send(request("tools/call", 1, {"name": "mock_wait", "arguments": {"milliseconds": 1000}}))
        h.process.stdin.close()
        self.assertEqual(h.process.wait(timeout=3), 0)
        self.assertEqual(h.process.stdout.read(), b"")

    def test_signal_wakes_idle_reader(self):
        h = self.helper
        h.send(request("ping"))
        h.receive()
        h.process.send_signal(signal.SIGTERM)
        self.assertEqual(h.process.wait(timeout=3), 0)

    def test_output_closure_and_backpressure_stop_without_hanging(self):
        h = self.helper
        h.process.stdout.close()
        h.send(request("ping"))
        self.assertNotEqual(h.process.wait(timeout=4), 0)
        other = Helper()
        self.addCleanup(other.close)
        # Small inbound batch, large replies; leave stdout unread to exercise the write deadline.
        other.send(b"".join(request("tools/list", n) for n in range(80)))
        self.assertNotEqual(other.process.wait(timeout=6), 0)

    def test_explicit_synthetic_mode_required(self):
        other = Helper(["--connection", "caller-asserted-identity"])
        self.addCleanup(other.close)
        self.assertEqual(other.process.wait(timeout=3), 64)
        self.assertEqual(other.process.stdout.read(), b"")
        self.assertNotIn(b"caller-asserted-identity", other.process.stderr.read())


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--executable", required=True)
    args = parser.parse_args()
    EXECUTABLE = os.path.abspath(args.executable)
    unittest.main(argv=[__file__], verbosity=2)
