--  SPDX-FileCopyrightText: 2024 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  This package provides a low-level interface for interacting with SPI flash
--  memory. Communication with the flash is performed through the exchange of
--  instruction bytes. Instructions can vary in length, ranging from a single
--  byte to several bytes, and may be followed by address bytes, data bytes,
--  dummy bytes (ignored), or combinations of these. The package enables users
--  to implement the actual read/write operations as they prefer, while
--  offering functionality to encode and decode instructions into
--  user-friendly formats.
--
--  For each instruction, the package defines a corresponding type or subtype
--  representing an array of bytes. Users exchange these byte arrays with
--  the flash memory and utilize the provided functions to encode or decode
--  instructions as needed.
--
--  NOTE: Users are responsible for sending and receiving the instruction
--  bytes to/from the flash!
--
--  Example usage:
--
--  1. To erase a sector:
--    - Call the `Sector_Erase` function to obtain the necessary instruction
--      bytes.
--    - Send the returned bytes to the flash memory. The flash will then erase
--      the specified sector.
--
--  2. To write data:
--    - Use the `Page_Program_Prefix` function to generate the instruction
--      bytes for the page program operation.
--    - Prepend these bytes to the data you want to write.
--    - Send the resulting byte array to the flash.
--
--  3. To read data:
--    - Create an array that includes the prefix returned by the
--      `Fast_Read_Prefix` function, followed by space for the data to be read.
--    - Exchange this array with the flash. The data retrieved from the flash
--      will be located immediately after the prefix in the array.


with Ada.Unchecked_Conversion;
with System;

package W25X.Raw is
   pragma Pure;

   Write_Enable  : constant Byte_Array := (1 => 16#06#);
   --  The Write Enable instruction sets the Write Enable Latch (WEL) bit in
   --  the Status Register.

   Write_Disable : constant Byte_Array := (1 => 16#04#);
   --  The Write Disable instruction resets the Write Enable Latch (WEL) bit
   --  in the Status Register.

   Power_Down    : constant Byte_Array := (1 => 16#B9#);
   --  Although the standby current during normal operation is relatively low,
   --  standby current can be further reduced with the Power-down instruction.

   Release_Power_Down : constant Byte_Array := (1 => 16#AB#);
   --  Release from power-down will take the time duration of tRES before the
   --  device will resume normal operation and other instructions are accepted

   Chip_Erase    : constant Byte_Array := (1 => 16#60#);
   --  The Chip Erase instruction sets all memory within the device to the
   --  erased state of all 1s (FFh). A Write Enable instruction must be
   --  executed before the device will accept the Chip Erase Instruction.

   subtype Block_Erase_Data is Byte_Array (1 .. 4);

   function Sector_Erase (Address : Interfaces.Unsigned_32)
     return Block_Erase_Data;
   --  The Sector Erase instruction sets all memory within a specified
   --  sector (4K-bytes) to the erased state of all 1s (FFh). A Write Enable
   --  instruction must be executed before the device will accept the Sector
   --  Erase Instruction.

   function Block_32K_Erase (Address : Interfaces.Unsigned_32)
     return Block_Erase_Data;
   --  The Block Erase instruction sets all memory within a specified block
   --  (32K-bytes) to the erased state of all 1s (FFh). A Write Enable
   --  instruction must be executed before the device will accept the
   --  Block Erase Instruction.

   function Block_64K_Erase (Address : Interfaces.Unsigned_32)
     return Block_Erase_Data;
   --  The Block Erase instruction sets all memory within a specified block
   --  (64K-bytes) to the erased state of all 1s (FFh). A Write Enable
   --  instruction must be executed before the device will accept the
   --  Block Erase Instruction.

   subtype Fast_Read_Prefix_Data is Byte_Array (1 .. 5);

   function Fast_Read_Prefix (Address : Interfaces.Unsigned_32)
     return Fast_Read_Prefix_Data;
   --  The Fast Read instruction is similar to the Read Data instruction
   --  except that it can operate at the highest possible frequency of FR.
   --  This is accomplished by adding eight “dummy” clocks after the 24-bit
   --  address. The dummy clocks allow the devices internal circuits
   --  additional time for setting up the initial address. During the
   --  dummy clocks the data value on the DO pin is a “don’t care”.

   subtype Page_Program_Prefix_Data is Byte_Array (1 .. 4);

   function Page_Program_Prefix (Address : Interfaces.Unsigned_32)
     return Page_Program_Prefix_Data;
   --  The Page Program instruction allows from one byte to 256 bytes (a page)
   --  of data to be programmed at previously erased (FFh) memory locations. A
   --  Write Enable instruction must be executed before the device will accept
   --  the Page Program Instruction.
   --
   --  If an entire 256 byte page is to be programmed, the last address byte
   --  (the 8 least significant address bits) should be set to 0. If the last
   --  address byte is not zero, and the number of clocks exceed the remaining
   --  page length, the addressing will wrap to the beginning of the page.

   type Read_JEDEC_ID_Data is record
      Data : Byte_Array (1 .. 4) := (16#9F#, 0, 0, 0);
   end record;
   --  Read_JEDEC_ID instruction fetches Manufacturer ID, Memory type and
   --  capacity bytes

   subtype JEDEC_ID is Byte_Array (1 .. 3);

   function Get_JEDEC_ID (Raw : Read_JEDEC_ID_Data) return JEDEC_ID is
     (JEDEC_ID (Raw.Data (2 .. 4)));

   W25Q16B : constant JEDEC_ID := (16#EF#, 16#40#, 16#15#);

   function Get_Capacity (Raw : Read_JEDEC_ID_Data) return Positive is
     (2 ** Natural (Raw.Data (4)));
   --  Return flash size in bits

   type Read_Status_Register_1_Data is record
      Data : Byte_Array (1 .. 2) := (16#05#, 0);
   end record;
   --  Read_Status_Register_1 instruction fetches Status_Register_1 byte

   type Status_Register_1 is record
      Busy : Boolean;  --  Erase, Program or Write cycle in progress
      WEL  : Boolean;  --  Write Enable Latch
      BP   : Natural range 0 .. 7;  --  Block protect
      TB   : Boolean;  --  Top/Bottom protect
      SEC  : Boolean;  --  Sector protect
      SPR0 : Boolean;  --  Status regirter protect 0
   end record
     with
       Size => 8,
       Bit_Order => System.Low_Order_First;

   function Get_Status_Register_1 (Raw : Read_Status_Register_1_Data)
     return Status_Register_1;

   type Read_Status_Register_2_Data is record
      Data : Byte_Array (1 .. 2) := (16#35#, 0);
   end record;
   --  Read_Status_Register_2 instruction fetches Status_Register_2 byte

   type Status_Register_2 is record
      SPR1     : Boolean;  --  Status regirter protect 1
      QE       : Boolean;  --  Quad Enable
      Reserved : Natural range 0 .. 0 := 0;
      SUS      : Boolean;  --  Suspend status
   end record
     with
       Size => 8,
       Bit_Order => System.Low_Order_First;

   function Get_Status_Register_2 (Raw : Read_Status_Register_2_Data)
     return Status_Register_2;

   type Status_Register is record
      BP   : Natural range 0 .. 7;  --  Block protect
      TB   : Boolean;  --  Top/Bottom protect
      SEC  : Boolean;  --  Sector protect
      SPR0 : Boolean;  --  Status regirter protect 0
      SPR1 : Boolean;  --  Status regirter protect 1
      QE   : Boolean;  --  Quad Enable
   end record;

   subtype Write_Status_Register_Data is Byte_Array (1 .. 3);

   function Write_Status_Register (Value : Status_Register)
     return Write_Status_Register_Data;
   --  The Write Status Register instruction allows the Status Register to be
   --  written. A Write Enable instruction must previously have been executed
   --  for the device to accept the Write Status Register Instruction.

private

   for Status_Register_1 use record
      Busy at 0 range 0 .. 0;
      WEL  at 0 range 1 .. 1;
      BP   at 0 range 2 .. 4;
      TB   at 0 range 5 .. 5;
      SEC  at 0 range 6 .. 6;
      SPR0 at 0 range 7 .. 7;
   end record;

   for Status_Register_2 use record
      SPR1     at 0 range 0 .. 0;
      QE       at 0 range 1 .. 1;
      Reserved at 0 range 2 .. 6;
      SUS      at 0 range 7 .. 7;
   end record;

   use type Interfaces.Unsigned_32;

   function Sector_Erase (Address : Interfaces.Unsigned_32)
     return Block_Erase_Data is
       (16#20#,
        Byte (Interfaces.Shift_Right (Address, 16) and 16#FF#),
        Byte (Interfaces.Shift_Right (Address, 8) and 16#FF#),
        Byte (Address and 16#FF#));

   function Block_32K_Erase (Address : Interfaces.Unsigned_32)
     return Block_Erase_Data is
       (16#52#,
        Byte (Interfaces.Shift_Right (Address, 16) and 16#FF#),
        Byte (Interfaces.Shift_Right (Address, 8) and 16#FF#),
        Byte (Address and 16#FF#));

   function Block_64K_Erase (Address : Interfaces.Unsigned_32)
     return Block_Erase_Data is
       (16#D8#,
        Byte (Interfaces.Shift_Right (Address, 16) and 16#FF#),
        Byte (Interfaces.Shift_Right (Address, 8) and 16#FF#),
        Byte (Address and 16#FF#));

   function Fast_Read_Prefix (Address : Interfaces.Unsigned_32)
     return Fast_Read_Prefix_Data is
       (16#0B#,
        Byte (Interfaces.Shift_Right (Address, 16) and 16#FF#),
        Byte (Interfaces.Shift_Right (Address, 8) and 16#FF#),
        Byte (Address and 16#FF#),
        0);

   function Page_Program_Prefix (Address : Interfaces.Unsigned_32)
     return Page_Program_Prefix_Data is
       (16#02#,
        Byte (Interfaces.Shift_Right (Address, 16) and 16#FF#),
        Byte (Interfaces.Shift_Right (Address, 8) and 16#FF#),
        Byte (Address and 16#FF#));

   function To_Reg_1 is new Ada.Unchecked_Conversion
     (Byte, Status_Register_1);

   function Get_Status_Register_1 (Raw : Read_Status_Register_1_Data)
     return Status_Register_1 is (To_Reg_1 (Raw.Data (2)));

   function To_Reg_2 is new Ada.Unchecked_Conversion
     (Byte, Status_Register_2);

   function Get_Status_Register_2 (Raw : Read_Status_Register_2_Data)
     return Status_Register_2 is (To_Reg_2 (Raw.Data (2)));

   function From_Reg_1 is new Ada.Unchecked_Conversion
     (Status_Register_1, Byte);

   function From_Reg_2 is new Ada.Unchecked_Conversion
     (Status_Register_2, Byte);

   function Write_Status_Register (Value : Status_Register)
     return Write_Status_Register_Data is
       (16#01#,
        From_Reg_1
          ((BP     => Value.BP,
            TB     => Value.TB,
            SEC    => Value.SEC,
            SPR0   => Value.SPR0,
            others => False)),
        From_Reg_2
          ((QE     => Value.QE,
            SPR1   => Value.SPR1,
            SUS    => False,
            others => 0)));

end W25X.Raw;
