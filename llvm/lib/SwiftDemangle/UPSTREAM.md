# Swift demangling source component

This component bundles a source subset of the official Swift project:

- Repository: https://github.com/swiftlang/swift
- Release: `swift-6.3.3-RELEASE`
- Commit: `064859e41d68596f486c5d724401cb370f260409`
- Archive: https://codeload.github.com/swiftlang/swift/tar.gz/064859e41d68596f486c5d724401cb370f260409
- Archive SHA-256: `a3a15dfa6e020c4fde3979d1f6839b4b41defd8e186d1b390c2b4b6284e7f45e`
- License: Apache 2.0 with Runtime Library Exception; the complete original
  text is in `vendor/swift/LICENSE.txt`.
- The release archive does not include `CONTRIBUTORS.txt`. The unmodified
  contributor notice in `vendor/swift/CONTRIBUTORS.txt` was obtained from
  https://www.swift.org/CONTRIBUTORS.txt on 2026-09-09.

The vendored subset contains the eleven translation units listed by the
release's `lib/Demangling/CMakeLists.txt` and their 22 required headers and
definition files. Their paths below `vendor/swift` retain their upstream
layout. No Swift compiler or runtime is built. The only LLVM library dependency
is Support, so this is a separate component from LLVMDemangle (which Support
itself depends on).

Local integration changes preserve each file's original copyright and license:

- A private inline namespace isolates this copy's C++ symbols.
- NodeFactory checks allocation arithmetic, allocation failure and cumulative
  slab memory before allocation. Parser node counts, character/stack operations,
  copies and recursive parser/remangler helpers consume an explicit budget.
- Temporary standard vectors and maps use a budgeted allocator; parser string
  growth and internal remangling string copies are checked before allocation.
- Punycode insertion work is counted by the number of elements it shifts.
- Internal demangler fatal/assert diagnostic paths return an error through the
  bounded wrapper instead of terminating the calling process.
- The wrapper copies the tree into owning standard C++ values with independent
  node/depth/allocation checks. It rejects runtime address references and control
  bytes, because this interface accepts symbol-table names, not live runtime
  memory. Context state and budget state are per call and per thread.

The wrapper and resource-accounting code are LLVM-project code under the LLVM
license; they are outside `vendor/swift`. Parser memory accounting is cumulative
and conservative, and excludes allocator bookkeeping and the fixed C++ call
stack. Requested tree depth is limited to 256; parser stack depth has a separate
finite bound. Unsupported or malformed names and exceeded budgets return a
nonempty error and no tree. Future Swift mangling versions may require updating
this pinned source subset and the matching regression tests.
