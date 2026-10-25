Native x86 compact-memory intrinsics
===================================

The fork supplies fixed-signature, side-effecting interfaces for the memory
forms of VPCOMPRESSB/W/D/Q, VCOMPRESSPS/PD, VPEXPANDB/W/D/Q and VEXPANDPS/PD.
These interfaces retain the actual instruction when its mask is zero or its
result is unused. They are separate from the generic masked-memory intrinsics,
whose optimizer contracts permit removing inactive memory operations.

``llvm.x86.avx512.compressstore{128,256,512}.native`` returns void and takes
``(ptr offset, i64 mask, <N x i32> source, i32 kind, i32 segment_prefix)``.
``llvm.x86.avx512.expandload{128,256,512}.native`` returns ``<N x i32>`` and
accepts ``(ptr offset, i64 mask, <N x i32> prior, i32 kind, i32 zeroing,
i32 segment_prefix)``. N is 4, 8 or 16. The vector is a raw-bit carrier;
kind selects bytes, words, dwords, qwords, packed single or packed double
(opcode selectors 0 through 5). Mask bits above the architectural lane count
are ignored. Zeroing is 0 for merging or 1 for zeroing inactive load lanes.
All three controls are immediate constants. Invalid controls are rejected.

The pointer represents a native-width, segment-relative offset. An EBX/RBX
carrier selects the default DS segment. Prefix is zero or an architectural
override byte: ``26, 2e, 36, 3e, 64, 65`` in hex. FS/GS base addition belongs
to the instruction, not an ordinary LLVM load. In long mode an explicit SS
prefix does not recreate the fault class of an RSP/RBP-based address; callers
must retain that distinction when projecting original machine addresses.
The interface does not encode an address-size override; callers normalize an
original narrower effective offset before converting it to the native pointer.

Functions require AVX512F, AVX512VL for 128/256-bit operations, and EVEX512
for 512-bit operations. Byte/word forms additionally require AVX512BW and
AVX512VBMI2. These attributes select code generation, not runtime dispatch.
The CPU still owns availability, suppression, access checks and faults.

IR effects remain conservative. Lowering creates a volatile, byte-aligned
machine memory operand with unknown access size; the active compact mask
controls the actual packed interval. No unmasked ordinary access substitutes
for the native memory instruction. Register and memory forms are never
interchanged by this interface. The i32 carrier avoids imposing AVX512BW on
dword/qword and floating-point forms.

``CodeGen/X86/avx512-native-compress-expand{,-invalid}.ll`` covers opcode
selection, zero-mask and dead-result preservation, i386/x64 modes, volatile
machine operands and invalid controls. Native AVX-512 execution and hardware
fault behavior need a separate hardware qualification.
