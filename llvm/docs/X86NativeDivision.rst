Native full-dividend integer division
====================================

The fixed ``llvm.x86.udivrem8/16/32/64`` and
``llvm.x86.sdivrem8/16/32/64`` interfaces take three equally sized integer
bit patterns: the low half of the dividend, its high half and the divisor.
They return a two-element struct containing the quotient and remainder at
that same width. Signedness belongs to the operation, including the entire
double-width dividend. The high half is never synthesized from the low half.

Each call executes one native DIV or IDIV. Unlike LLVM integer division,
a zero divisor or an unrepresentable quotient raises the architectural #DE;
it does not produce poison, a truncated quotient, a fabricated result or a
runtime library call. The original processor and OS own fault handling.
The result values exist only after successful instruction completion.
Arithmetic flags are undefined and are not returned. The compiler ABI owns
all other registers and the stack; these are not original-PC continuations.

The operations are nounwind, convergent and noduplicate with conservative
memory effects. Unused or repeated calls remain and retain their position
relative to surrounding memory operations. Integer inputs are SSA values;
reading a source pointer is a separate operation, not a memory DIV encoding.
Native instruction effects also keep machine scheduling from speculating or
eliminating the divide. The byte interface packs and reads complete AX,
avoiding AH copies to REX-only registers.

All widths are available in code64, including x32. Code32 admits 8, 16 and
32 bits. The 64-bit operand requires code64. Code16 is diagnosed explicitly.
The ``native-divrem.ll`` regression checks both optimization levels and
backend pass managers, ELF/COFF/Mach-O, unused results, memory ordering,
both outputs, signatures and mode errors.

The architectural reference is the Intel SDM DIV/IDIV instruction entries:
https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html
