`ifndef TEST_DEFS_DONE
	`define TEST_DEFS_DONE

	`include "definitions.sv"

	package TestTypes;
		const int BufferLen = (2**`BUF_ADDR_WIDTH);
		typedef logic [`BUF_DATA_WIDTH-1:0] BufData_t;
		typedef logic [`BUF_ADDR_WIDTH-1:0] BufAddress_t;	
		typedef logic [`ROW_ADDR_WIDTH-1:0] MemRowAddr_t;
		typedef logic [`MEM_DATA_WIDTH-1:0] MemData_t;
		typedef logic [`COL_ADDR_WIDTH-1:0] ColAddr_t;
		typedef logic [$clog2(`BLOCK_NUM)-1:0] BlockAddr_t; //
		typedef logic [$clog2(`BLOCK_LEN)-1:0] PageOffset_t; // 
	endpackage
	
	import TestTypes::*;
	
`endif
