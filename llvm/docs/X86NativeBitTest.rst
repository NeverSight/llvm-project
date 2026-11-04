Native X86 memory bit strings
=============================

``llvm.x86.{bt,bts,btr,btc}.mem{16,32,64}`` returns an ``i8`` carry value
(0 or 1) and accepts ``ptr base, iN signed_bit_index``. The suffix selects
the word, dword or qword operand width. These calls select one original
memory BT/BTS/BTR/BTC followed by a carry capture when used. They never
lower to inline assembly or a C load/shift/store expansion.

The full signed index participates in native bit-string addressing. A
negative index may access preceding words; large indices may access following
words. Constant indices retain these register-index semantics. They must not
be changed to an imm8 form that silently masks their high bits.

The native operation owns its complete operand access and architectural
faults, even when its return value is unused. Calls have conservative memory
effects, nounwind, convergent and noduplicate attributes. The machine memory
operand has unknown address and extent, alignment one, and volatile load
(and, for updating forms, store) effects. A fixed-width memory range at
``base`` would be incorrect for this API. These intrinsics do not add LOCK
or promise atomicity with other processors. Existing ``llvm.x86.atomic.*.rm``
intrinsics retain their separate LOCK semantics.

Widths 16 and 32 support code16, code32 and code64. Code16 uses LLVM's
32-bit pointer/stack ABI, with native mode-correct address and operand
prefixes. Width 64 requires long mode and is explicitly refused elsewhere.
These pointer interfaces do not expose arbitrary segment overrides or
address-size controls. Carry is their only flag output, and compiler ABI
state remains compiler-owned.

``llvm/test/CodeGen/X86/native-bit-strings.ll`` checks native instructions,
carry, negative constants, dead effects, code modes and machine verification.
The NeverC repository's ``verify_native_bit_tests.py`` adds independent native
instruction, RAM and signal/fault comparisons for generated i386/x64 code.
