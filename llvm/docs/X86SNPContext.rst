Native SNP completion and SEV-ES guest exits
==========================================

This fork provides eight x86-64 register-completion intrinsics::

  declare void @llvm.x86.psmash.context(ptr, ptr, i32 immarg)
  declare void @llvm.x86.pvalidate.context(ptr, ptr, i32 immarg)
  declare void @llvm.x86.rmpadjust.context(ptr, ptr, i32 immarg)
  declare void @llvm.x86.rmpupdate.context(ptr, ptr, i32 immarg)
  declare void @llvm.x86.rmpquery.context(ptr, ptr, i32 immarg)
  declare void @llvm.x86.rmpread.context(ptr, ptr, i32 immarg)
  declare void @llvm.x86.rmpopt.context(ptr, ptr, i32 immarg)
  declare void @llvm.x86.rmpchkd.context(ptr, ptr, i32 immarg)

The first pointer addresses three unaligned u64 slots in RAX, RCX, RDX order;
the second addresses an unaligned u64 flags snapshot. Only architectural output
registers and modified arithmetic flags are published. Other slots and flag
bits retain the supplied values. In particular, RMPOPT has no GPR outputs;
RMPQUERY returns all three registers; RMPCHKD returns RAX and RCX and records
the actual values of its four undefined arithmetic flags. PVALIDATE consumes
ECX and EDX, not their high halves. Status writes to EAX zero-extend normally.
``X86SnpState.h`` owns the register and flag masks.

Control bit 0 selects PVALIDATE's address32 form; other operations reject it.
Bits 15:8 optionally contain one segment-prefix byte (26, 2e, 36, 3e, 64, 65
hexadecimal). All remaining bits must be zero. The instruction owns segment
and paging interpretation. Context pointers remain full-width default-address-
space pointers even when the instruction's operand uses another segment.

These operations have unknown memory effects and are convergent, noduplicate
and nounwind. They do not promise successful completion, willreturn, nosync,
nofree or argument-memory-only effects. Native CPU privilege, feature, RMP,
paging, restart and SNP state remain architectural. The context, flags object
and compiler frame must be accessible and disjoint from one another and from
instruction-owned memory and RMP/mapping changes. Fault or restart register
state is not an exception image in the context: only normal completion publishes
outputs. The caller must provide exception handling appropriate to native
execution. SNP-capable AMD processors supply long-mode LAHF/SAHF; flags are
captured without a compiler-stack push or a red-zone/unwind interval.

The separate returning SEV-ES interface is::

  declare void @llvm.x86.vmgexit.sev(i64)

RAX supplies the optional VMGEXITParameter. GHCB/shared-memory and MSR service
communication remains in the native environment. The contract requires SEV-ES,
restoration of private CPU state and preservation of the compiler execution
environment. It excludes non-SEV-ES VMMCALL fallback and services replacing the
caller state. The backend emits canonical F3 0F 01 D9; the disassembler accepts
both F2 and F3 forms. The intrinsic remains an ordered, convergent, noduplicate
operation with unknown memory effects, even though it has no SSA result.

The frontend-facing APIs are in NeverC's ``snpcontextintrin.h``. No inline
assembly or unresolved external helper is needed. Other code modes fail
explicitly; assembler recognition of a 16/32-bit PVALIDATE or VMGEXIT does not
supply a corresponding native completion API.

Tests cover O0/O2, both LLVM pass managers, ELF/COFF/Mach-O objects, exact
encodings, immediate and mode refusal, conservative optimization effects and
F2/F3 disassembly. NeverC's independent raw-byte/PUSHFQ fixture uses a controlled
Linux signal service to compare register/flags transport, unaligned objects,
live integer/FP values and fault-before-publication. This fixture does not
qualify real AMD RMP algorithms or SEV-ES services.

References: AMD64 Architecture Programmer's Manual, Volume 3, publication
24594 revision 3.39 (October 2026), instruction entries PSMASH through RMPUPDATE
and VMGEXIT; Volume 2, publication 24593, sections 15.35.6--15.35.8; and the
`GHCB specification <https://www.amd.com/content/dam/amd/en/documents/epyc-technical-docs/specifications/56421.pdf>`_.
