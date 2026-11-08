//===- MCPointerAuthInfo.h - Pointer authentication recipe --------*- C++
//-*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_MC_MCPOINTERAUTHINFO_H
#define LLVM_MC_MCPOINTERAUTHINFO_H

#include <cstdint>

namespace llvm {

enum class MCPointerAuthKey : uint8_t {
#define MC_POINTER_AUTH_KEY(Name, Value) Name = Value,
#include "llvm/MC/MCPointerAuthInfo.def"
};

/// Signing recipe carried by a native authenticated-pointer expression. This
/// describes runtime signing; it is not an already signed address. Address
/// diversity uses the pointer's final storage address, not its target address.
struct MCPointerAuthInfo {
  MCPointerAuthKey Key = MCPointerAuthKey::IA;
  uint16_t Discriminator = 0;
  bool HasAddressDiversity = false;

  bool operator==(const MCPointerAuthInfo &Other) const {
    return Key == Other.Key && Discriminator == Other.Discriminator &&
           HasAddressDiversity == Other.HasAddressDiversity;
  }
};

} // namespace llvm

#endif // LLVM_MC_MCPOINTERAUTHINFO_H
