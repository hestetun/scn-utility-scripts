#!/usr/bin/env python3
"""Exercise the real cache script with a fake mount and a blocking fake fcp."""

import fcntl
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


SCRIPT = Path(__file__).with_name("facilis-cache.sh")


class OverlapTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="facilis-lock-test-")
        self.root = Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)
        self.children = []
        self.addCleanup(self.stop_children)
        (self.root / "bin").mkdir()
        (self.root / "volumes" / "test_edit" / "Avid MediaFiles").mkdir(parents=True)
        self.release = self.root / "release"
        self.starts = self.root / "starts"
        self.script = self.root / "facilis-cache.sh"
        text = SCRIPT.read_text().replace(
            "/tmp/com.scn.facilis-cache.lock", str(self.root / "cache.lock")
        ).replace("/Volumes/", str(self.root / "volumes") + "/")
        self.script.write_text(text)
        self.write_command("pgrep", "exit 1")
        self.write_command("xattr", "exit 0")
        self.write_command("mount", 'printf "mock on %s (apfs)\\n" '
                           '"$TEST_ROOT/volumes/test_edit" "$TEST_ROOT/volumes/dpos_edit"')
        # Widen the old lock's mkdir-before-PID window deterministically.
        self.write_command(
            "mkdir", '/bin/mkdir "$@"; result=$?; case "${*: -1}" in '
            '"$TEST_ROOT/cache.lock") sleep 0.2;; esac; exit "$result"'
        )
        self.write_command(
            "fake-fcp", 'echo "$$" >> "$TEST_ROOT/starts"\n'
            'printf "%s\\n" "$2" >> "$TEST_ROOT/paths"\n'
            'while [[ ! -e "$TEST_ROOT/release" ]]; do sleep 0.05; done'
        )
        self.env = os.environ.copy()
        self.env.update(
            HOME=str(self.root), TEST_ROOT=str(self.root),
            FCP_BIN=str(self.root / "bin" / "fake-fcp"),
            PATH=str(self.root / "bin") + ":/usr/bin:/bin:/usr/sbin:/sbin",
        )

    def write_command(self, name, body):
        path = self.root / "bin" / name
        path.write_text("#!/bin/bash\n" + body + "\n")
        path.chmod(0o755)

    def start(self):
        child = subprocess.Popen(
            ["/bin/bash", str(self.script)], env=self.env,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        self.children.append(child)
        return child

    def start_count(self):
        return len(self.starts.read_text().splitlines()) if self.starts.exists() else 0

    def wait_for(self, predicate, timeout=5):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.02)
        self.fail("Timed out waiting for test condition")

    def stop_children(self):
        self.release.touch()
        for child in self.children:
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()

    def test_simultaneous_starts_do_not_overlap(self):
        for _ in range(12):
            self.start()
        self.wait_for(lambda: self.start_count() >= 1)
        time.sleep(0.6)
        self.assertEqual(self.start_count(), 1, "more than one fcp ran concurrently")

    def test_lock_survives_killed_parent_until_fcp_finishes(self):
        first = self.start()
        self.wait_for(lambda: self.start_count() == 1)
        first.kill()
        first.wait(timeout=3)
        second = self.start()
        time.sleep(1)
        self.assertEqual(self.start_count(), 1, "fcp overlapped after its parent died")
        self.release.touch()
        second.wait(timeout=3)
        lock = self.root / "cache.lockfile"

        def lock_available():
            with lock.open("r") as handle:
                try:
                    fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
                except BlockingIOError:
                    return False
                return True

        self.wait_for(lock_available)
        third = self.start()
        third.wait(timeout=3)
        self.assertEqual(self.start_count(), 2, "a new run should start after fcp finishes")

    def test_symlink_lock_is_rejected(self):
        (self.root / "cache.lockfile").symlink_to(self.root / "other-file")
        process = self.start()
        self.assertNotEqual(process.wait(timeout=3), 0)
        self.assertEqual(self.start_count(), 0)

    def test_caches_both_media_folders(self):
        volume = self.root / "volumes" / "dpos_edit"
        avid = volume / "Avid MediaFiles"
        from_set = volume / "editorial" / "media" / "_from-set"
        avid.mkdir(parents=True)
        from_set.mkdir(parents=True)
        self.env["SOURCE_VOL"] = str(volume)
        self.release.touch()
        process = self.start()
        self.assertEqual(process.wait(timeout=3), 0)
        self.assertEqual((self.root / "paths").read_text().splitlines(),
                         [str(avid), str(from_set)])

    def test_from_set_is_cached_even_when_avid_folder_is_missing(self):
        volume = self.root / "volumes" / "dpos_edit"
        from_set = volume / "editorial" / "media" / "_from-set"
        from_set.mkdir(parents=True)
        self.env["SOURCE_VOL"] = str(volume)
        self.release.touch()
        process = self.start()
        self.assertEqual(process.wait(timeout=3), 0)
        self.assertEqual((self.root / "paths").read_text().splitlines(), [str(from_set)])

    def test_other_volumes_also_cache_from_set(self):
        volume = self.root / "volumes" / "test_edit"
        (volume / "editorial" / "media" / "_from-set").mkdir(parents=True)
        self.env["SOURCE_VOL"] = str(volume)
        self.release.touch()
        process = self.start()
        self.assertEqual(process.wait(timeout=3), 0)
        self.assertEqual((self.root / "paths").read_text().splitlines(),
                         [str(volume / "Avid MediaFiles"),
                          str(volume / "editorial" / "media" / "_from-set")])

    def test_error_in_one_folder_does_not_skip_the_other(self):
        volume = self.root / "volumes" / "dpos_edit"
        avid = volume / "Avid MediaFiles"
        from_set = volume / "editorial" / "media" / "_from-set"
        avid.mkdir(parents=True)
        from_set.mkdir(parents=True)
        self.env["SOURCE_VOL"] = str(volume)
        self.write_command("fake-fcp", 'printf "%s\\n" "$2" >> "$TEST_ROOT/paths"\n'
                           '[[ "$2" != */"Avid MediaFiles" ]] || exit 4')
        process = self.start()
        self.assertEqual(process.wait(timeout=3), 4)
        self.assertEqual((self.root / "paths").read_text().splitlines(),
                         [str(avid), str(from_set)])


if __name__ == "__main__":
    unittest.main()
