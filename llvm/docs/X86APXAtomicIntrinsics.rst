Native x86 atomic intrinsics
===========================

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

Legacy RAO and VEX CMPccXADD
---------------------------

Ten additional ``llvm.x86.{aadd,aand,aor,axor,cmpccxadd}{32,64}.legacy.address``
intrinsics have the same x86-64 signatures, controls and effects as their APX
counterparts. They preserve legacy RAO or VEX CMPccXADD encoding. Separate
machine pseudos constrain every data operand to ``GR32_NOREX2`` or
``GR64_NOREX2`` before register allocation; CMPccXADD's comparator is tied to
its result. This remains true when inputs arrive in APX-only registers.
Feature availability is determined by the retained instruction encoding.

Four ``llvm.x86.{aadd,aand,aor,axor}32.legacy.address32`` interfaces support
i386 code mode. They take ``(i32 offset, i32 source, i32 address_bits,
i32 segment_prefix)`` and return void. Address width is 16 or 32; the offset
wraps before segment-base addition. The address carrier is BX or EBX, with
the same DS default and explicit segment controls as the x86-64 interfaces.
Code mode and address width are independent: the x86-64 forms reject i386
code mode, and the i386 forms reject x86-64 code mode.

``CodeGen/X86/legacy-native-atomic{,-i386,-invalid,-egpr}.ll`` checks these
contracts, including copies out of R20--R22 into encodable data registers.
Use ``--legacy`` with NeverC's completion oracle to qualify the legacy/VEX
matrix. Each x86-64 route checks 10,080 functions, 120,960 controlled
completions and twelve assembly round trips across the six optimization and
object-format profiles. These are encoding, transport and compiler-effect
checks; hardware atomicity, memory-type behavior and faults remain unqualified.

The older pointer-taking RAO-INT/CMPccXADD, atomic bit-test and conditional
arithmetic intrinsics also carry no implicit alignment promise. Their machine
memory operands use byte alignment, retain volatile read/write effects and
leave architectural faults to the instruction. Previously the bit width was
misinterpreted as byte alignment. The 48 cases in
``CodeGen/X86/atomic-intrinsic-memory-alignment.ll`` cover 8/16/32/64-bit
operations at O0/O2 and with APX register allocation enabled.
