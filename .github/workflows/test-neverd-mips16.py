"""Qualify the MIPS codegen pipeline from the checked-out LLVM fork commit."""

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
          "-DLLVM_ENABLE_PROJECTS=clang;lld", "-DLLVM_INCLUDE_TESTS=ON",
          "-DLLVM_INCLUDE_BENCHMARKS=OFF", "-DLLVM_INCLUDE_EXAMPLES=OFF",
          "-DLLVM_ENABLE_ZSTD=OFF", "-DLLVM_ENABLE_ZLIB=OFF",
          "-DLLVM_ENABLE_LIBXML2=OFF"]
if windows:
    config += ["-DCMAKE_C_COMPILER=clang-cl", "-DCMAKE_CXX_COMPILER=clang-cl"]
elif platform.system() == "Linux":
    config += ["-DCMAKE_C_COMPILER=clang", "-DCMAKE_CXX_COMPILER=clang++",
               "-DLLVM_USE_LINKER=lld"]
run("configure", config)
run("standalone-parser", ["cmake", "--build", build, "--target",
                          "LLVMMipsAsmParser", "--parallel", "4"])
run("build", ["cmake", "--build", build, "--target", "llc", "FileCheck",
              "llvm-mc", "llvm-objdump", "llvm-config", "llvm-readobj", "not", "count",
              "llvm-readelf", "llvm-dwarfdump", "obj2yaml", "split-file", "opt", "llvm-as",
              "clang", "lld", "yaml2obj", "MCTests", "TargetParserTests",
              "--parallel", "4"])
suffix = ".exe" if windows else ""
write("products.json", {name: hashlib.sha256(
    (build / "bin" / (name + suffix)).read_bytes()).hexdigest()
    for name in ("llc", "FileCheck", "llvm-mc", "llvm-objdump", "clang")})
# Module preparation changes the common pass pipeline. Enumerate the complete
# MIPS suite through lit, including MIR tests, rather than filename prefixes.
test_inputs = [root / "llvm/test/CodeGen/Mips", root / "llvm/test/MC/Mips",
               root / "llvm/test/MC/Disassembler/Mips"]
lit = build / "bin" / ("llvm-lit.py" if windows else "llvm-lit")
listed = output([sys.executable, lit, "--show-tests", *test_inputs])
tests = sorted(root / "llvm/test" / line.strip().split(" :: ", 1)[1]
               for line in listed.splitlines() if " :: " in line)
assert tests and len(tests) == len(set(tests))
write("inventory.json", {str(path.relative_to(root)):
                         hashlib.sha256(path.read_bytes()).hexdigest()
                         for path in tests})
run("lit", [sys.executable, lit, "-v", "-j", "4",
            "--xunit-xml-output", evidence / "results.xml", *test_inputs])
lld_suite = root / "lld/test/ELF"
lld_listed = output([sys.executable, lit, "--show-tests", lld_suite])
lld_inputs = sorted(root / "lld/test" / line.strip().split(" :: ", 1)[1]
                    for line in lld_listed.splitlines() if " :: ELF/" in line
                    and "mips" in line.rsplit("/", 1)[-1].lower())
assert lld_inputs
write("lld-inventory.json", {str(path.relative_to(root)):
                             hashlib.sha256(path.read_bytes()).hexdigest()
                             for path in lld_inputs})
run("lld-lit", [sys.executable, lit, "-v", "-j", "4",
                "--xunit-xml-output", evidence / "lld-results.xml", *lld_inputs])
run("mips-final-fixups", [build / "unittests/MC" / ("MCTests" + suffix),
                         "--gtest_filter=BinaryRewriteRelocationTest.MicroMips*:"
                         "BinaryRewriteRelocationTest.Mips64R6*",
                         "--gtest_output=xml:" + str(evidence / "mips-final-fixups.xml")])
run("target-layout", [build / "unittests/TargetParser" /
                      ("TargetParserTests" + suffix),
                      "--gtest_filter=DataLayoutTest.*",
                      "--gtest_output=xml:" + str(evidence / "target-layout.xml")])
clang_tests = [root / "clang/test/CodeGen" / name for name in
               ("mips-function-pointer-tag.c", "mips16-attr.c",
                "micromips-attr.c", "target-data.c")]
write("clang-inventory.json", {str(path.relative_to(root)):
                               hashlib.sha256(path.read_bytes()).hexdigest()
                               for path in clang_tests})
run("clang-lit", [sys.executable, lit, "-v", "-j", "4",
                  "--xunit-xml-output", evidence / "clang-results.xml",
                  *clang_tests])
write("complete.json", {"source": source, "test_files": len(tests), "exit": 0})
