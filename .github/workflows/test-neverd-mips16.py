"""Qualify MIPS16 code generation from the checked-out LLVM fork commit."""

import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
build = root / "build-mips16"
evidence = root / "mips16-evidence"
evidence.mkdir(exist_ok=True)


def output(command):
    return subprocess.check_output(command, cwd=root, text=True).strip()


def write(name, value):
    (evidence / name).write_text(json.dumps(value, indent=2) + "\n")


def run(name, command):
    write(name + "-command.json", [str(item) for item in command])
    with (evidence / (name + ".log")).open("w") as log:
        result = subprocess.run(command, cwd=root, stdout=log,
                                stderr=subprocess.STDOUT)
    write(name + "-result.json", {"exit": result.returncode})
    if result.returncode:
        print((evidence / (name + ".log")).read_text(errors="replace")[-16000:])
        raise SystemExit(result.returncode)


source = output(["git", "rev-parse", "HEAD"])
status = output(["git", "status", "--porcelain", "--untracked-files=no"])
assert not status, status
write("source.json", {"source": source,
                      "tree": output(["git", "rev-parse", "HEAD^{tree}"]),
                      "platform": platform.platform(),
                      "python": sys.version})
windows = os.name == "nt"
config = ["cmake", "-S", root / "llvm", "-B", build, "-G", "Ninja",
          "-DCMAKE_BUILD_TYPE=Release", "-DLLVM_TARGETS_TO_BUILD=Mips",
          "-DLLVM_ENABLE_RTTI=ON", "-DLLVM_ENABLE_ASSERTIONS=ON",
          "-DLLVM_ENABLE_PROJECTS=", "-DLLVM_INCLUDE_TESTS=ON",
          "-DLLVM_INCLUDE_BENCHMARKS=OFF", "-DLLVM_INCLUDE_EXAMPLES=OFF",
          "-DLLVM_ENABLE_ZSTD=OFF", "-DLLVM_ENABLE_ZLIB=OFF",
          "-DLLVM_ENABLE_LIBXML2=OFF"]
if windows:
    config += ["-DCMAKE_C_COMPILER=clang-cl", "-DCMAKE_CXX_COMPILER=clang-cl"]
elif platform.system() == "Linux":
    config += ["-DCMAKE_C_COMPILER=clang", "-DCMAKE_CXX_COMPILER=clang++",
               "-DLLVM_USE_LINKER=lld"]
run("configure", config)
run("build", ["cmake", "--build", build, "--target", "llc", "FileCheck",
              "llvm-mc", "llvm-objdump", "llvm-config", "llvm-readobj", "not", "count",
              "--parallel", "4"])
suffix = ".exe" if windows else ""
write("products.json", {name: hashlib.sha256(
    (build / "bin" / (name + suffix)).read_bytes()).hexdigest()
    for name in ("llc", "FileCheck", "llvm-mc", "llvm-objdump")})
# Existing mixed-mode and hard-float cases run beside all new regressions.
test_dir = root / "llvm/test/CodeGen/Mips"
tests = sorted(set(test_dir.glob("mips16*.ll")) |
               set(test_dir.glob("fp16*.ll")) | {test_dir / "nomips16.ll"})
write("inventory.json", {str(path.relative_to(root)):
                         hashlib.sha256(path.read_bytes()).hexdigest()
                         for path in tests})
run("lit", [sys.executable, build / "bin/llvm-lit", "-v", "-j", "4",
            "--xunit-xml-output", evidence / "results.xml", *tests])
write("complete.json", {"source": source, "test_files": len(tests), "exit": 0})
