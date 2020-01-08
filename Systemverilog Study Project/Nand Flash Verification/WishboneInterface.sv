`include "definitions.sv"

`timescale 1 ns / 1 fs

interface wishbone 
(input clk_i,			// System clock
input rst_i); 			// System reset

// Wishbone Interconnect signals
logic [`WB_ADDR_WIDTH-1:0] wb_addr;			// Address bus
logic 					   wb_we; 			// Write / Read
logic 					   wb_stb; 			// Slave select strobe
logic 					   wb_cyc; 			// Wishbone cycle
logic					   wb_ack; 			// slave acknowledge

logic [`WB_DATA_WIDTH-1:0] wb_data_i_s; 	// Slave data input bus
logic [`WB_DATA_WIDTH-1:0] wb_data_o_s; 	// Slave data output bus
logic [`WB_DATA_WIDTH-1:0] wb_data_i_m; 	// Master data input bus
logic [`WB_DATA_WIDTH-1:0] wb_data_o_m; 	// Master data output bus


assign wb_data_i_s = wb_data_o_m; 
assign wb_data_i_m = wb_data_o_s;

// Master and Slave modports

modport Slave (input  clk_i,
			   input  rst_i,
			   input  wb_addr,
			   input  wb_data_i_s,
			   input  wb_we,
			   input  wb_stb,
			   input  wb_cyc,
			   output wb_ack,
			   output wb_data_o_s
			   );

modport Master (input  clk_i,
				input  rst_i,
				input  wb_data_i_m, 
				input  wb_ack,
				output wb_addr,
				output wb_data_o_m,
				output wb_we,
				output wb_stb,
				output wb_cyc,
				import task GetFlashByte 		(input logic [(`ROW_ADDR_WIDTH + `COL_ADDR_WIDTH) - 1 : 0] ByteAddress, output [`BUF_DATA_WIDTH-1:0] Byte),
				import task SetFlashByte 		(input logic [(`ROW_ADDR_WIDTH + `COL_ADDR_WIDTH) - 1 : 0] ByteAddress, input [`BUF_DATA_WIDTH-1:0] Byte),
				import task ProgramFlashPage 	(input logic [`ROW_ADDR_WIDTH-1:0] PageAddress),
				import task ReadFlashPage		(input logic [`ROW_ADDR_WIDTH-1:0] PageAddress),
				import task EraseFlashBlock 	(input logic [`ROW_ADDR_WIDTH-1:0] BlockAddress),
				import task ReadBuffer 			(input logic [`WB_ADDR_WIDTH-1:0] Address, output logic [`WB_DATA_WIDTH-1:0] Data),
				import task WriteBuffer			(input logic [`WB_ADDR_WIDTH-1:0] Address, input logic [`WB_DATA_WIDTH-1:0] Data),
				import task ErrorRead			(output logic [2:0] errors),
				import task ReadyRead			(output logic Ready),
				import task ReadFlashID			(output logic [3:0][`BUF_DATA_WIDTH-1:0] FlashID),
				import task ResetFlash()
				);
						
				
/*****************
Lower level WISHBONE read and write tasks (not imported to the Master)
*****************/

task wb_MasterWrite (input logic [`WB_ADDR_WIDTH-1:0] Address, input logic [`WB_DATA_WIDTH-1:0] Data); 
begin
wb_stb = 1'b1; 			
wb_cyc = 1'b1;
wb_addr = Address;	
wb_data_o_m = Data;  		
wb_we = 1'b1;			
@(posedge clk_i iff wb_ack == 1);
wb_stb = 1'b0;
wb_cyc = 1'b0;
end
endtask

task wb_MasterRead (input logic [`WB_ADDR_WIDTH-1:0] Address, output logic [`WB_DATA_WIDTH-1:0] Data);
begin
wb_stb = 1'b1;
wb_cyc = 1'b1;
wb_addr = Address;
wb_we = 1'b0;
@(posedge clk_i iff wb_ack ==1);
Data = wb_data_i_m;
wb_stb = 1'b0;
wb_cyc = 1'b0;
end
endtask


/*********************
PROCESS TASKS (imported ONLY to the host modport)
*********************/

task GetFlashByte (input logic [(`ROW_ADDR_WIDTH + `COL_ADDR_WIDTH) - 1 : 0] ByteAddress, output [`BUF_DATA_WIDTH-1:0] Byte);
	ReadFlashPage (ByteAddress[`ROW_ADDR_WIDTH + `COL_ADDR_WIDTH - 1 : `COL_ADDR_WIDTH]);
	ReadBuffer (ByteAddress[`COL_ADDR_WIDTH-1:0], Byte);
endtask

task SetFlashByte (input logic [(`ROW_ADDR_WIDTH + `COL_ADDR_WIDTH) - 1 : 0] ByteAddress, input [`BUF_DATA_WIDTH-1:0] Byte);
	ReadFlashPage (ByteAddress[`ROW_ADDR_WIDTH + `COL_ADDR_WIDTH - 1 : `COL_ADDR_WIDTH]);
	WriteBuffer (ByteAddress[`COL_ADDR_WIDTH-1:0], Byte);
	ProgramFlashPage (ByteAddress[`ROW_ADDR_WIDTH + `COL_ADDR_WIDTH - 1 : `COL_ADDR_WIDTH]);
endtask

task ProgramFlashPage (input logic [`ROW_ADDR_WIDTH-1:0] PageAddress);
	wb_MasterWrite(`ROW_ADDR, PageAddress);
	wb_MasterWrite(`NFC_CMD, `NFC_PROGRAM_PAGE);
	WaitDone();
endtask


task ReadFlashPage (input logic [`ROW_ADDR_WIDTH-1:0] PageAddress);
	wb_MasterWrite(`ROW_ADDR, PageAddress);
	wb_MasterWrite(`NFC_CMD, `NFC_READ_PAGE);
	WaitDone();
endtask



task EraseFlashBlock (input logic [`ROW_ADDR_WIDTH-1:0] BlockAddress);
	wb_MasterWrite(`ROW_ADDR, BlockAddress);
	wb_MasterWrite(`NFC_CMD, `NFC_BLOCK_ERASE);
	WaitDone();
endtask


task ResetFlash();
	wb_MasterWrite(`NFC_CMD, `NFC_RESET);
	WaitDone();
endtask

task ReadBuffer (input logic [`WB_ADDR_WIDTH-1:0] Address, output logic [`WB_DATA_WIDTH-1:0] Data);
begin
	wb_MasterRead(Address[`BUF_ADDR_WIDTH-1:0], Data[`BUF_DATA_WIDTH-1:0]);
end
endtask

task WriteBuffer(input logic [`WB_ADDR_WIDTH-1:0] Address, input logic [`WB_DATA_WIDTH-1:0] Data);
begin
	wb_MasterWrite(Address[`BUF_ADDR_WIDTH-1:0], Data[`BUF_DATA_WIDTH-1:0]);
end
endtask

task ErrorRead(output logic [2:0] errors);
begin
	wb_MasterRead(`NFC_ERROR, errors);
end
endtask

task ReadyRead(output logic Ready);
begin
	wb_MasterRead(`NFC_READY, Ready);
end
endtask

task ReadFlashID(output logic [3:0][`BUF_DATA_WIDTH-1:0] FlashID);
	wb_MasterWrite(`ROW_ADDR, '0);
	wb_MasterWrite(`NFC_CMD, `NFC_READ_ID);
	WaitDone();
	for (int i=1; i<5; i++)
	begin
		ReadBuffer (i, FlashID[i-1]);
	end
endtask


/********* 
Intermediate tasks
**********/

task WaitDone();
begin
logic Done;
logic [2:0] Errors;
	Done = 1'b0;
	while (!Done)
	begin
		HostIF.ReadyRead(Done);
	end
	$display ($time, ": Flash operation completed");
	HostIF.ErrorRead(Errors);
	$display ($time, ": Operation resulted in: Program Error = %b, Erase Error = %b, Read (ECC) Error = %b", Errors[2], Errors[1], Errors[0]);
end
endtask
endinterface