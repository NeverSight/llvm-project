Native X86 FLAGS images
======================

``llvm.x86.flags.read.u16()`` returns an ``i16`` snapshot using word PUSHF
and a word pop into a register. ``llvm.x86.flags.write.u16(i16)`` pushes
that exact word and executes word POPF. Both are available in code16,
code32 and code64. The matching Clang builtin spellings are
``__builtin_ia32_readeflags_u16`` and ``__builtin_ia32_writeeflags_u16``.

The existing ``u32`` interfaces require a non-long code mode; ``u64``
requires long mode. The word interface cannot be implemented by extending
its operand to a wider write: word POPF leaves AC and ID unchanged, while
POPFD/POPFQ may replace them. Native CPL/IOPL restrictions, reserved bits,
RF clearing, stack accesses and processor faults remain architectural.

These operations retain conservative memory effects, including unused
snapshots. Machine pseudos keep the complete push/pop pair until register
allocation, use GR16 for the word carrier, and reserve compiler stack
storage. Writes define EFLAGS and DF. Frame-pointer and red-zone handling
apply to every width; a temporary push must not overwrite live spills.
Code16 follows LLVM's 32-bit pointer/stack ABI. This is a compiler-owned
stack interface, not an original-image register or fault continuation.

The builtins observe or change the processor's flags at the native
instruction. They do not make arithmetic flags live across arbitrary C
expressions, function prologues or intervening compiler instructions.

``flags16.ll`` covers widths, code modes, retained dead effects, memory
ordering and machine verification. ``red-zone.ll`` covers stack ownership.
``clang/test/CodeGen/X86/flags16-builtins.c`` covers frontend signatures.
