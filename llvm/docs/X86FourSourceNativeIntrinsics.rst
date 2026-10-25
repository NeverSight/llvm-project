Native x86 four-source arithmetic intrinsics
===========================================

The six ``llvm.x86.avx512.{v4fmaddps,v4fnmaddps,v4fmaddss,v4fnmaddss,
vp4dpwssd,vp4dpwssds}.native`` interfaces keep each four-iteration operation
in one architectural instruction. Each returns a raw i32 vector and accepts
``(ptr offset, vector accumulator, vector source0, vector source1,
vector source2, vector source3, i16 mask, i32 zeroing, i32 segment_prefix)``.
Scalar SS carriers contain four i32 elements; all other carriers contain 16.
The scalar result preserves accumulator bits 127:32, including with zeroing.
Mask bits above bit 0 for scalar forms, or bit 15 for packed forms, are ignored.

All four sources are independent SSA operands. Lowering places them in the
aligned XMM4..7 or ZMM4..7 group and records the three unencoded physical
register uses on the machine instruction. Register allocation and scheduling
must retain those uses; a single unconstrained vector input cannot represent
the architectural source block. The accumulator may be independent of all
four sources. No ordinary floating-point or integer arithmetic substitutes for
the four sequential rounding, exception or saturation boundaries.

Zeroing is a constant 0 or 1. Segment prefix is a constant architectural
override byte (0, 26, 2e, 36, 3e, 64 or 65 in hex). The pointer is a
native-width, segment-relative offset carried in EBX/RBX for default DS
addressing. FS/GS base addition and the mask-controlled 16-byte memory access
remain instruction-owned. Callers must retain any distinct default-stack fault
provenance and normalize narrower effective offsets before using this API.

IR memory and synchronization effects are conservative. A volatile, unknown-size,
byte-aligned memory operand preserves zero-mask and unused-result instructions.
AVX512F and (for packed carriers) EVEX512 are required by the register types.
Actual execution additionally requires the processor's AVX512_4FMAPS or
AVX512_4VNNIW instruction capability and enabled extended state; the intrinsic
does not introduce runtime dispatch or imply that AVX512F alone provides it.

The CodeGen tests cover both native word sizes, optimization, all four physical
source uses, dead/zero-mask retention and invalid controls. They do not qualify
physical Xeon Phi execution or hardware exception delivery.

Integration qualification also assembles all six operations at O0/O2 for
i386 and x86-64 ELF, COFF and Mach-O. A separate bounded interpreter checks
the x86-64 ELF probe's physical register and stack transfers with distinct
accumulator/source values and a recorded result token, including all three
calls and preservation of callee-saved registers. This validates transport;
the native arithmetic and hardware exceptions remain unexecuted.
