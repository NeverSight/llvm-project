//===- Mips.h - MIPS ELF relocation encoding --------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_BINARYFORMAT_ELFRELOCS_MIPS_H
#define LLVM_BINARYFORMAT_ELFRELOCS_MIPS_H

#include <cstdint>

namespace llvm::ELF {
// O32 REL stores the word addend in linear order. The linked MIPS16 JAL or
// JALX exchanges the upper two five-bit fields of the 26-bit word address.
constexpr uint32_t encodeMips16JumpField(uint32_t word) {
  return (word & 0xffff) | ((word & 0x1f0000) << 5) | ((word & 0x3e00000) >> 5);
}

// MIPS16 EXTEND holds imm[10:5] and imm[15:11] in the first halfword.
// The instruction following it holds imm[4:0], in either byte order.
constexpr uint32_t encodeMips16Imm16(uint16_t imm) {
  return (uint32_t(imm & 0x7e0) << 16) | ((imm & 0xf800) << 5) | (imm & 31);
}

constexpr uint16_t decodeMips16Imm16(uint32_t insn) {
  return ((insn >> 16) & 0x7e0) | ((insn >> 5) & 0xf800) | (insn & 31);
}
} // namespace llvm::ELF

#endif
