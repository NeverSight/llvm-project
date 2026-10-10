#!/usr/bin/env python3
"""Run the release admission step against a local, offline GitHub API stub."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import textwrap
import unittest


def release_script():
    workflow = Path(__file__).with_name("neverd-release.yml").read_text()
    step = workflow.split("      - name: Resolve and validate release\n", 1)[1]
    lines = step.split("        run: |\n", 1)[1].splitlines()
    script = []
    for line in lines:
        if line and not line.startswith("          "):
            break
        script.append(line[10:] if line else "")
    return "\n".join(script) + "\n"


class ReleaseAdmission(unittest.TestCase):
    def setUp(self):
        for executable in ("bash", "jq"):
            self.assertIsNotNone(shutil.which(executable), executable)
        self.temporary = tempfile.TemporaryDirectory(prefix="neverd-release-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        version = self.root / "cmake/Modules/LLVMVersion.cmake"
        version.parent.mkdir(parents=True)
        version.write_text(
            "set(LLVM_VERSION_MAJOR 23)\n"
            "set(LLVM_VERSION_MINOR 0)\n"
            "set(LLVM_VERSION_PATCH 0)\n"
        )
        self.bin = self.root / "bin"
        self.bin.mkdir()
        curl = self.bin / "curl"
        curl.write_text(textwrap.dedent("""\
            #!/usr/bin/env python3
            import json
            import os
            from pathlib import Path
            import sys
            args = sys.argv[1:]
            Path(os.environ['TEST_API_CALLED']).touch()
            output = Path(args[args.index('--output') + 1])
            output.write_text(json.dumps({
                'immutable': os.environ['TEST_IMMUTABLE'] == 'true'
            }))
            print(os.environ['TEST_HTTP_STATUS'], end='')
            """))
        curl.chmod(0o755)

    def resolve(
        self, event="push", status="200", overwrite="false",
        immutable="false", tag="neverd-llvm-v23.0.0-r4",
    ):
        output = self.root / "output"
        called = self.root / "api-called"
        environment = dict(
            os.environ,
            PATH=str(self.bin) + os.pathsep + os.environ["PATH"],
            EVENT_NAME=event,
            REF_NAME=tag,
            DISPATCH_TAG=tag,
            DISPATCH_OVERWRITE=overwrite,
            GH_TOKEN="unused-offline-test-token",
            GITHUB_API_URL="https://invalid.example",
            GITHUB_REPOSITORY="example/llvm-project",
            GITHUB_OUTPUT=str(output),
            RUNNER_TEMP=str(self.root),
            TEST_API_CALLED=str(called),
            TEST_HTTP_STATUS=status,
            TEST_IMMUTABLE=immutable,
        )
        result = subprocess.run(
            ["bash", "-c", release_script()], cwd=self.root,
            env=environment, text=True, capture_output=True, timeout=10,
        )
        values = (
            dict(line.split("=", 1) for line in output.read_text().splitlines())
            if output.exists() else {}
        )
        return result, values, called.exists()

    def test_tag_push_preserves_an_existing_release(self):
        result, values, called = self.resolve()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already exists", result.stderr)
        self.assertEqual(values, {})
        self.assertTrue(called)

    def test_new_tag_never_grants_replacement_at_publication(self):
        result, values, called = self.resolve(status="404", overwrite="true")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(values["publish"], "true")
        self.assertEqual(values["overwrite"], "false")
        self.assertEqual(values["release_exists"], "false")
        self.assertTrue(called)

    def test_manual_replacement_requires_explicit_input(self):
        result, values, _ = self.resolve(event="workflow_dispatch")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("already exists", result.stderr)
        self.assertEqual(values, {})

    def test_explicit_manual_replacement_is_retained(self):
        result, values, _ = self.resolve(
            event="workflow_dispatch", overwrite="true")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(values["overwrite"], "true")
        self.assertEqual(values["release_exists"], "true")

    def test_immutable_release_cannot_be_replaced(self):
        result, values, _ = self.resolve(
            event="workflow_dispatch", overwrite="true", immutable="true")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("immutable", result.stderr)
        self.assertEqual(values, {})

    def test_lookup_failure_is_not_an_absent_release(self):
        result, values, called = self.resolve(status="503")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("HTTP 503", result.stderr)
        self.assertEqual(values, {})
        self.assertTrue(called)

    def test_wrong_version_never_reaches_the_api(self):
        result, values, called = self.resolve(tag="neverd-llvm-v22.0.0-r4")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not match", result.stderr)
        self.assertEqual(values, {})
        self.assertFalse(called)

    def test_artifact_only_dispatch_does_not_query_a_release(self):
        result, values, called = self.resolve(event="workflow_dispatch", tag="")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(values["publish"], "false")
        self.assertFalse(called)


if __name__ == "__main__":
    unittest.main()
