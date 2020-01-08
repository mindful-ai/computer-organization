`include "definitions.sv"
`timescale 1 ns / 1 fs

`define N `MEM_DATA_WIDTH // TODO: same as data-width

interface NandFlashInterface
(
input SysReset  // System Reset
);
  
wire [`N-1:0] DIO;			// Data Inputs/Outputs 
logic CLE;					// Command Latch Enable 
logic ALE;					// Address Latch Enable logic 
logic WE_n;					// Write Enable
logic RE_n; 				// Read Enable
logic CE_n; 				// Chip Enable
logic R_nB; 				// Ready/Busy 


modport Controller  (inout DIO,
					input R_nB,
					output CLE,
					output ALE,
					output WE_n,
					output RE_n,
					output CE_n
					);
					

modport Memory (inout DIO,
			   input CLE,
			   input ALE,
			   input WE_n,
			   input RE_n,
			   input CE_n,
			   output R_nB,
			   import CommandLatch,
			   import AddressLatch,
			   import DataLatch,
			   import SendData
			   );
			   


string CmdLabel [logic [`N-1:0] ];
initial
begin
CmdLabel [`PAGE_READ ]  = "PAGE_READ";
CmdLabel [`BEGIN_READ] = "BEGIN_READ";
CmdLabel [`READ_ID] = "READ_ID";
CmdLabel [`RESET] = "RESET";
CmdLabel [`PAGE_PROGRAM] = "PAGE_PROGRAM";
CmdLabel [`CONFIRM_PROGRAM] = "CONFIRM_PROGRAM";
CmdLabel [`BLOCK_ERASE] = "BLOCK_ERASE";
CmdLabel [`BEGIN_ERASE] = "BEGIN_ERASE";
CmdLabel [`RANDOM_READ] = "RANDOM_READ";
CmdLabel [`RANDOM_WRITE_1 ] = "RANDOM_WRITE_1";
CmdLabel [`RANDOM_WRITE_2] = "RANDOM_WRITE_2";
CmdLabel [`READ_STATUS] = "READ_STATUS";
end

			   
task CommandLatch (output logic [`N-1:0] Command);
Command = DIO;
`ifdef DEBUG_MEM_MODEL
$display ($time, ": Latching Command: %h (%s)", Command, CmdLabel[Command]); 
`endif
endtask

task AddressLatch (output logic [`N-1:0] Address);
Address = DIO;
`ifdef DEBUG_MEM_MODEL
$display ($time, ": Latched Address: %h", Address); 
`endif
endtask

task automatic DataLatch (ref logic [`N-1:0] Data);
Data = DIO;
endtask


endinterface


/* TODO

-- Dat_en signal?
1. Import tasks to Flash modport
2. Define CMDstring Associative Array in definitions.sv for task CommandLatch
3. Print Setup command or Execute command 
4.Print Prohibited command using INSIDE op in CommandLatch


*/
