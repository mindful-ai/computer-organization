`include "definitions.sv"

`timescale 1 ns / 1 fs


module memory_stub 
(
NandFlashInterface MemPort,
input ResetStub
);

// TIMING PARAMETERS
parameter tWB = 60;
parameter tBERS = 200;
parameter tR = 260;
parameter tPROG = 200;
parameter tRHZ = 70;
parameter tRHZ2 = 50;
parameter tSTAT = 151;



logic [`MEM_DATA_WIDTH-1:0] MemArray [`BLOCK_LEN*`BLOCK_NUM][`COLUMN_WIDTH];			  // Array for NAND flash memory 

logic [`MEM_DATA_WIDTH-1:0] ColumnCache [`COLUMN_WIDTH];  	  // Array for temporarily storing data before 10h (confirm-write) command issued


// Control/Status Registers 
logic [`COMMAND_WIDTH:0] Command, PrevCommand; 
logic [`STATUS_REG_WIDTH-1:0] Status;
logic [`COL_ADDR_WIDTH-1:0] ColumnAddr;
logic [`ROW_ADDR_WIDTH-1:0] RowAddr;
logic [`MEM_DATA_WIDTH-1 :0] DummyAddress; // For READ ID operation

logic OE; // ***



// Call relevant task from interface based upon MUX signals (ALE/CLE) when write strobe is asserted

always @ (posedge MemPort.WE_n, ResetStub)
begin
if (ResetStub)
begin
Command = '0;
Status = '0;
ColumnAddr = '0;
RowAddr = '0;
DummyAddress = '0;
end

else if (!MemPort.CE_n && MemPort.CLE && !MemPort.ALE) // COMMAND CYCLE
begin
	PrevCommand = Command;
	MemPort.CommandLatch(Command);
	
	if (Command == 8'h10) // CONFIRM WRITE OPERATION 
	begin
		if (PrevCommand == 8'h85)
		begin
		MemArray [RowAddr] = ColumnCache; // Commit 
		
		`ifdef DEBUG_MEM_MODEL
		  for (int k =0; k <10; k++)
			$display ("Copied to row: %0d at %0d = : %0d", RowAddr, k, MemArray[RowAddr][k]);
		`endif	
		end
		
		else $display ($time, ": Error! CONFIRM_PROGRAM Command Issued before PROGRAM_PAGE command");
	end
	
	else if (Command == 8'hD0) // BLOCK ERASE
		begin
		if (PrevCommand == 8'h60)
	    BlockErase (RowAddr);
		
		else $display ($time, ": Error! BEGIN_ERASE Command Issued before BLOCK_ERASE command");
	   end
	   
	else if (Command == 8'hFF) // RESET
	  begin
	  Command = 8'h00; // Reset command register to abort current operation (BUG: issuing reset between commands not supported by controller)
	  end 
	   
end

else if (!MemPort.CE_n && !MemPort.CLE && MemPort.ALE) // ADDRESS CYCLE
begin
case (Command)
	'h60: // BLOCK ERASE
			begin
				MemPort.AddressLatch(RowAddr[`MEM_DATA_WIDTH-1:0]);  // Least significant byte of row address
				@ (posedge MemPort.WE_n); // *** 
				MemPort.AddressLatch(RowAddr[(`MEM_DATA_WIDTH * 2) - 1: `MEM_DATA_WIDTH]);  // Most significant byte of row address
				
				RowAddr[5:0] = '0;  // Override page address to 0 because erase is performed on entire block
				
				$display($time, ": Block address for erase = %0h", RowAddr);
			end
			
	'h80, 'h00: // PAGE READ, PAGE PROGRAM
			begin
				MemPort.AddressLatch(ColumnAddr[`MEM_DATA_WIDTH-1:0]);
				@ (posedge MemPort.WE_n); 
				MemPort.AddressLatch(ColumnAddr[`COL_ADDR_WIDTH-1: `MEM_DATA_WIDTH]); // *** 2
				@ (posedge MemPort.WE_n); // *** 
				MemPort.AddressLatch(RowAddr[`MEM_DATA_WIDTH-1:0]);  
				@ (posedge MemPort.WE_n); // *** 
				MemPort.AddressLatch(RowAddr[(`MEM_DATA_WIDTH * 2) - 1: `MEM_DATA_WIDTH]);  
				
				if (Command == 'h80)
				$display($time, ": Page row address for Program = %0h", RowAddr);
				else 
				$display($time, ": Page row address for Read = %0h", RowAddr);
			end	
			
	'h85, 'h05: // RANDOM READ, RANDOM WRITE
			begin
				MemPort.AddressLatch(ColumnAddr[`MEM_DATA_WIDTH-1:0]);
				@ (posedge MemPort.WE_n); // *** 
				MemPort.AddressLatch(ColumnAddr[`COL_ADDR_WIDTH-1 - 1: `MEM_DATA_WIDTH]); // *** 2
				
				$display ($time, ": Random I/O column address = %0h", ColumnAddr);
			end
			
	8'h90: // READ ID
			begin
				MemPort.AddressLatch(DummyAddress);	
				
				$display ($time, ": Dummy Address for read ID = %0h", DummyAddress);
			end
	endcase
end
end


// PROGRAM tasks 
always @ (posedge MemPort.WE_n or ResetStub)
begin
logic [11:0] data_counter, ecc_counter; 
int i, j;
if (ResetStub)
begin
ecc_counter = 2100;
data_counter = '0;
end

else if (!MemPort.CE_n && !MemPort.ALE && !MemPort.CLE) // DATA CYCLE
begin
	if (Command == 8'h80) // PROGRAM
	begin
		MemPort.DataLatch (ColumnCache [data_counter]);

		
		`ifdef DEBUG_MEM_MODEL
			if (data_counter < 10 || ( data_counter >2039 && data_counter <2048 ) || (data_counter >50 && data_counter <68)) 
			       $display ("This is being written to %0d : %0d", data_counter, ColumnCache[data_counter]);
		`endif	
		
		if (data_counter == 2047) 	
			data_counter = 0;
		else 
			data_counter = data_counter + 1'b1;
	
			end
	
	else if (Command == 8'h85) // RANDOM_WRITE
	begin
		MemPort.DataLatch (ColumnCache [ecc_counter]);
		
    if (ecc_counter == 2111)
      ecc_counter = 2100;
    else
		  ecc_counter = ecc_counter + 1'b1;
	end
	
	else if (Command == 8'h70) // READ STATUS
	begin
	 MemPort.DataLatch (Status);
	end
	
	else 
	begin
	  data_counter = 0;
	  ecc_counter = 2100;
	end
	
end 
end



// Read ID counter
logic [1:0] counter_RD_ID;

always @ (negedge MemPort.RE_n or ResetStub)
 if(ResetStub) begin
  counter_RD_ID <= 0;
 end else if(!MemPort.CE_n && !MemPort.ALE && !MemPort.CLE && Command==8'h90) begin 
  counter_RD_ID <= counter_RD_ID + 1; 
 end 
 
 
// READ tasks
logic [11:0] data_counter_rd, ecc_counter_rd; 
logic [`MEM_DATA_WIDTH-1:0] data_out;
logic data_read_complete, ecc_read_complete;

always @ (negedge MemPort.RE_n or ResetStub)
begin
if (ResetStub)
	begin
	data_counter_rd <= 0;
	ecc_counter_rd <= 2100;
	data_read_complete <= 0;
	//ecc_read_complete = 0;
	end

else
if (!MemPort.CE_n && !MemPort.ALE && !MemPort.CLE )
begin
	if (Command == 8'h30) // BEGIN READ OPERATION
	begin
		data_out = MemArray [RowAddr][data_counter_rd];
		
		`ifdef DEBUG_MEM_MODEL			if (data_counter_rd < 10 || ( data_counter_rd >2039 && data_counter_rd <2048) || (data_counter_rd >50 && data_counter_rd <68) ) 
		                $display ("This is being read from %0d : %0d", data_counter_rd, MemArray[RowAddr][data_counter_rd]);
		`endif	

		if (data_counter_rd == 2047)
			begin
			data_read_complete =1;
			data_counter_rd <= 0;
			end
		else
		  begin 
			data_read_complete <=0;
			data_counter_rd <= data_counter_rd + 1'b1;
			end
							
	end
	
	else if (Command == 8'hE0) // RANDOM OUTPUT OPERATION
	begin
		data_out = MemArray [RowAddr][ecc_counter_rd];
		data_read_complete <= 0; // *** 2
		
		if (ecc_counter_rd == 2111)
      ecc_counter_rd <=2100;
    else
		  ecc_counter_rd <= ecc_counter_rd + 1'b1;
	end
	
	else if (Command == 8'h90) // READ ID OPERATION
	begin
		data_counter_rd <= 0;
		ecc_counter_rd <= 2100;
		
		case (counter_RD_ID) // TODO: Display in transcript?
		2'b00: data_out = `MANUFACTURER_CODE;
		2'b01: data_out = `DEVICE_CODE;
		2'b10: data_out = 0;
		2'b11: data_out = `CYCLE_ID;
		endcase
	end
	
	else
	begin
		data_counter_rd <= 0;
		ecc_counter_rd <= 12'd2100;
		data_out <= 0;
		data_read_complete <= 0;
	end
end
end
 
 
//assign MemPort.DIO = (!MemPort.CE_n && !MemPort.ALE && !MemPort.CLE && (Command==8'h30 || Command==8'h90 ||Command==8'he0 || Command == 8'h70)) ? data_out:8'hzz;
							
assign MemPort.DIO = OE ? data_out : 'hzz;


always@(negedge MemPort.RE_n or ResetStub or data_counter_rd or ecc_counter_rd) 
begin

if(ResetStub) 
begin  
  OE<=0;   
end 

else if(!MemPort.CE_n && !MemPort.ALE && !MemPort.CLE)
begin
	case (Command)
	
	8'h30: begin
			if(!data_read_complete)
				OE<=1;
			else
				#(tRHZ) OE<=0; // 70
			end
			
	8'hE0: begin 
			if(ecc_counter_rd != 2111)
				OE<=1;
			else
				#(tRHZ2) OE<=0; // 50 ***
			end
  
	8'h90: begin 
				OE<=1;
				#(tRHZ) OE<=0;  
			end
	endcase
end  

else if (Command == 8'h70)
			begin
				OE<=1;
				#(tSTAT) OE<=0; // 151
			end  
end  
  

always @ (MemPort.RE_n or ResetStub or MemPort.CE_n or MemPort.ALE or MemPort.CLE or MemPort.WE_n) 
begin
 if(ResetStub) 
 begin
  MemPort.R_nB<=1;
 end 
 
 else if (Command == 8'hd0 || Command == 8'h10 ||Command == 8'h30) 
 begin
 case (Command)
	8'hd0: begin 
			#(tWB) 		MemPort.R_nB<=0; 
			#(tBERS)  	MemPort.R_nB<=1; 
		   end
	
	8'h10: begin 
			#(tWB)		MemPort.R_nB<=0; 
			#(tPROG)    MemPort.R_nB<=1; 
		  end
	
	8'h30: begin 
			#(tWB)		 MemPort.R_nB<=0; 
			#(tR-tWB) 	 MemPort.R_nB<=1; 
		  end 
endcase
end

else MemPort.R_nB<=1;
end


task automatic BlockErase(logic [`ROW_ADDR_WIDTH-1:0] RowAddr);
	automatic int PageIndex = 0;
	while (PageIndex !== `BLOCK_LEN)
	begin
	MemArray[RowAddr + PageIndex] = '{default: '1}; 
	PageIndex++;
  end
endtask


endmodule