--  SPDX-FileCopyrightText: 2024 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with Interfaces;

package W25X is
   pragma Pure;

   subtype Byte is Interfaces.Unsigned_8;  --  Instruction or memory value

   type Byte_Array is array (Positive range <>) of Byte;
   --  Bytes that make up the instructions.

end W25X;
