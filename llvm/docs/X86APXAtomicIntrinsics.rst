Native APX atomic intrinsics
============================

The fork provides ten fixed-signature intrinsics for EVEX-encoded RAO-INT and
CMPccXADD in 64-bit code mode. They preserve native memory transactions instead
of expanding them into ordinary loads, stores or compare/exchange loops.

``llvm.x86.{aadd,aand,aor,axor}{32,64}.address`` return void and take
``(i64 offset, iN source, i32 address_bits, i32 segment_prefix)``, where N is
32 or 64. ``llvm.x86.cmpccxadd{32,64}.address`` return the old memory value as
``iN`` and take ``(i64 offset, iN compare, iN add, i32 condition,
i32 address_bits, i32 segment_prefix)``. The condition is the architectural
condition-code number in [0, 15]. All controls must be constants.

Address width is 32 or 64. A 32-bit address wraps before the CPU adds the
segment base, and retains the native address-size override. Segment is zero
for the DS default or an override byte: ``26, 2e, 36, 3e, 64, 65`` in hex.
The integer offset is not an LLVM pointer in the default address space.
RBX supplies the DS-default base; the allocator preserves its incoming C ABI
value. No synthetic FS/GS-base access is introduced.

An indivisible machine pseudo retains the address and EVEX controls until MC
lowering. Object output and both assembly dialects preserve EVEX even when
ordinary GPRs would permit another encoding. CPU availability remains the
caller's responsibility; unavailable instructions retain their native faults.
Invalid code mode, address width, segment or condition is rejected.

The intrinsics conservatively read and write unknown memory and synchronize.
Dead results cannot remove the instruction, and repeated calls cannot be
commoned. In particular, a false CMPccXADD condition still performs native
write-back. CMPccXADD defines EFLAGS; RAO-INT preserves EFLAGS. The interface
does not promise pointer alignment, cacheability or successful completion.
Architectural checks and memory faults belong to the native instruction.

``CodeGen/X86/apx-native-atomic{,-invalid}.ll`` exercises lowering, retained
dead effects, flags, address controls and invalid operands. NeverC's
``tests/verify-apx-atomic-completion.py`` covers both widths, all sixteen
conditions, seven segment choices, live/dead/repeated calls, O0/O2 and
ELF/COFF/MachO. It independently decodes the atomic bytes and executes the
surrounding code with controlled completions, including ordinary-memory
aliasing and nonvolatile registers. ATT/Intel assembly round trips compare
every effective instruction's bytes and address, excluding alignment NOPs.
These tests do not establish physical atomicity, coherence or CPU fault
behavior on APX hardware.
