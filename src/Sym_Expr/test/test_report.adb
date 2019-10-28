----------------------------------------------------------------------------
--            Symbolic Expressions (symexpr)
--
--               Copyright (C) 2012, Riccardo Bernardini
--
--      This file is part of symexpr.
--
--      symexpr is free software: you can redistribute it and/or modify
--      it under the terms of the Lesser GNU General Public License as published by
--      the Free Software Foundation, either version 3 of the License, or
--      (at your option) any later version.
--
--      symexpr is distributed in the hope that it will be useful,
--      but WITHOUT ANY WARRANTY; without even the implied warranty of
--      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--      GNU General Public License for more details.
--
--      You should have received a copy of the Lesser GNU General Public License
--      along with gclp.  If not, see <http://www.gnu.org/licenses/>.
----------------------------------------------------------------------------

with Ada.Strings.Fixed;

package body Test_Report is
   function Pad_To (What : String; To   : Positive)
                    return String
   is
      use Ada.Strings.Fixed;
   begin
      if What'Length < To then
         return (To - What'Length) * " " & What;
      else
         return What;
      end if;
   end Pad_To;

   procedure Be_Verbose (This : in out Reporter_Type;
                         Flag : in     Boolean := True) is
   begin
      This.Verbose := Flag;
   end Be_Verbose;

   procedure Set_Tab (This : in out Reporter_Type;
                      Tab  : in     Positive) is
   begin
      This.Tab := Tab;
   end Set_Tab;


   procedure Close_Suite (This : in out Reporter_Type) is
      Suite_Name : constant String := To_String (This.Name);
   begin
      if (This.N_Tests = 0) then
         return;
      end if;

      if (Suite_Name /= "") then
         declare
            Buf : constant String := "     Test suite '" & Suite_Name & "'";
         begin
            if (This.Tab <= Buf'Length) then
               This.Tab := Buf'Length + 1;
            end if;
            if This.Tab > Buf'Length then
               Put (File => This.Output_To.all,
                    Item => Buf
                    & To_String ((This.Tab - Buf'Length) * '.'));
            else
               Put (File => This.Output_To.all,
                    Item => Buf & "...");

               This.Tab := Buf'Length + 3;
            end if;

            Put (File => This.Output_To.all,
                 Item => " passed ");
         end;
      else
         Put (File => This.Output_To.all,
              Item => "Passed ");
      end if;

      declare
         Plural : String := "s";
      begin
         if (This.N_Test_Ok = 1) then
            Plural := " ";
         end if;

         Put (File => This.Output_To.all,
              Item => Pad_To (Positive'Image (This.N_Test_OK), 3)
              & " test" & Plural & " out of "
              & Pad_To (Natural'Image (This.N_Tests), 3)
              & ": ");
      end;

      if (This.N_Tests = This.N_Test_OK) then
         This.N_Suite_OK := This.N_Suite_OK + 1;
         Put_Line (File => This.Output_To.all,
                   Item => "SUCCESS");
      else
         Put (File => This.Output_To.all,
              Item => "FAILURE");
         Put ("  ");

         declare
            use Boolean_Lists;

            Position : Cursor;
         begin
            Position := This.Suite_Results.First;
            while Position /= No_Element loop
               if Element (Position) then
                  Put ("+");
               else
                  Put ("-");
               end if;

               Next (Position);
            end loop;
         end;

         This.Status := Ada.Command_Line.Failure;
      end if;

      This.N_Tests   := 0;
      This.N_Test_OK := 0;
      This.N_Suites  := This.N_Suites + 1;
   end Close_Suite;

   procedure Final (This       : in out Reporter_Type;
                    Set_Status : in     Boolean := True) is

      function Plural(X : Natural) return String is
      begin
         if (X = 1) then
            return "";
         else
            return "s";
         end if;
      end Plural;


   begin
      if (This.N_Suites = 0 and This.N_Tests = 0) then
         return;
      end if;

      -- Put_Line ("XXX" & Integer'Image (This.N_Tests));

      if (This.N_Tests > 0) then
         Close_Suite(This);
      end if;

      if (This.N_Suites > 1) then
         New_Line (File => This.Output_To.all);

         Put (File => This.Output_To.all,
              Item => "Passed "
              & Pad_To (Integer'Image (This.N_Suite_OK), 3)
              & " test suite" & Plural (This.N_Suite_OK) & " out of "
              & Pad_To (Integer'Image (This.N_Suites), 3)
              & ": ");

         if (This.N_Suites = This.N_Suite_OK) then
            Put_Line(File => This.Output_To.all,
                     Item => "SUCCESS");
         else
            Put_Line(File => This.Output_To.all,
                     Item => "FAILURE");
         end if;
      end if;

      if (Set_Status) then
         Ada.Command_Line.Set_Exit_Status(This.Status);
      end if;
   end Final;


   procedure New_Suite (This : in out Reporter_Type;
                        Name : in     String := "") is

   begin
      if (This.Verbose) then
         Put_line (This.Output_To.all,  "New test suite " & Name);
      end if;

      -- Put_Line ("YYY" & Integer'Image (This.N_Tests));

      if (This.N_Tests /= 0) then
         Close_Suite(This);
      end if;

      This.Name := To_Unbounded_String (Name);
      This.Suite_Results.Clear;
   end New_Suite;

   procedure Success (This : in out Reporter_Type) is
   begin
      New_Result (This, True);
   end Success;

   procedure Failure (This : in out Reporter_Type) is
   begin
      New_Result (This, False);
   end Failure;

   procedure New_Result (This : in out Reporter_Type;
                         Ok   : in     Boolean) is
   begin
      if (This.Verbose) then
         if (Ok) then
            Put_line (This.Output_To.all, "Success");
         else
            Put_line (This.Output_To.all, "FAILURE");
         end if;
      end if;

      This.N_Tests := This.N_Tests + 1;
      if (Ok) then
         This.N_Test_OK := This.N_Test_OK + 1;
      end if;

      This.Suite_Results.Append (OK);
   end New_Result;

   procedure Do_Suite (This  : in out Reporter_Type;
                       Cases : in     Test_Case_Array;
                       Name  : in     String := "") is
   begin
      New_Suite(This, Name);
      for I in Cases'Range loop
         if (This.Verbose) then
            Put (File => This.Output_To.all,
                 Item => "Test # " & Positive'Image(I) & " ");
         end if;

         New_Result(This, Check(Cases(I)));
      end loop;
   end Do_Suite;

   procedure Set_Output (This : in out Reporter_Type;
                         File : in     File_Access) is
   begin
      This.Output_To := File;
   end Set_Output;
end Test_Report;

   -- -- function "and" (X, Y : Ada.Command_Line.Exit_Status)
   -- --                return Ada.Command_Line.Exit_Status is
   -- -- begin
   -- --    if (X = Ada.Command_Line.Success) then
   -- --       return Y;
   -- --    else
   -- --       return Ada.Command_Line.Failure;
   -- --    end if;
   -- -- end "and";
   --
   -- procedure Do_Report (This        : in out Reporter_Type;
   --                      Num_Trials  : in     Positive;
   --                      Num_Success : in     Natural;
   --                      Name        : in     String  := "";
   --                      Set_Status  : in     Boolean := True)
   -- is
   --
   -- begin
   --    This.N_Suites := This.N_Suites + 1;
   --
   --    if (Name /= "") then
   --       Put ("Test " & Name & ": passed ");
   --    else
   --       Put ("Passed ");
   --    end if;
   --
   --    Put (Positive'Image(Num_Success)
   --           & " tests out of "
   --           & Natural'Image(Num_Trials)
   --           & ": ");
   --
   --    if (Num_Success = Num_Trials) then
   --       This.N_Suite_OK := This.N_Suite_OK + 1;
   --       Put_Line ("SUCCESS");
   --    else
   --       Put_Line ("FAILURE");
   --       This.Status := Ada.Command_Line.Failure;
   --    end if;
   --
   --    if (Set_Status) then
   --       Ada.Command_Line.Set_Exit_Status(This.Status);
   --    end if;
   -- end Do_Report;
