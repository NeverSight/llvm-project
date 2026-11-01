Native HLE operation contexts
=============================

``llvm.x86.hle.context(ptr memory, ptr gprs, ptr flags, i32 control, i32 bytes)``
executes one legal HLE memory instruction in 64-bit mode. Both integer controls
are immediate. The operation numbers, supported widths and register effects
are defined in ``llvm/IR/X86HleState.h``. The memory pointer addresses the
instruction's memory operand in the native flat address space. The context
does not install segment bases or address-size wrapping. Byte-sized bit
operations, acquire MOV and unlisted instructions are rejected.

The GPR object contains four unaligned 64-bit slots, in RAX/RCX/RDX/RBX order.
RCX supplies the explicit source or signed register bit index. CMPXCHG uses
RAX as its comparison operand; CMPXCHG8B uses all four implicit registers.
The flags object is a separate unaligned 64-bit snapshot. Inputs retain their
native operand widths, outputs retain native subregister semantics, and flags
outside the instruction's output mask retain their supplied values. Undefined
output flags come from the executing CPU. The native processor must support
long-mode LAHF/SAHF and the selected underlying instruction.

Control bit 8 chooses acquire rather than release. The native prefix and memory
instruction are emitted together, and the operation retains unknown memory
effects, convergence and no-duplication. It must not be replaced with an
unprefixed atomic instruction. Both context objects, the compiler stack and the
instruction memory must be disjoint and accessible for normal completion.
Native faults are not serialized into the context objects.

With bit 9 clear, the caller owns the complete HLE critical region, including
nesting, rollback and every continuation that could execute before release.
This interface alone does not turn arbitrary split interpreter steps into an
owned transaction. Context writes are transactional while HLE is active.

Bit 9 requests a standalone completion boundary. It requires entry outside
RTM and any external HLE transaction. A native PAUSE executes immediately after
the memory operation and before any output publication. Intel SDM Volume 1,
section 17.3.9.1, guarantees PAUSE aborts an active transaction. On HLE abort,
the processor restores the acquire checkpoint and retries that instruction
without elision. Publication therefore occurs only after native nontransactional
completion. This retains an actual acquire/retry and never fabricates success.
On processors without HLE the legal hints are ignored by the processor, as
specified by the architecture. Physical HLE commit/abort qualification remains
distinct from testing that native fallback path.
