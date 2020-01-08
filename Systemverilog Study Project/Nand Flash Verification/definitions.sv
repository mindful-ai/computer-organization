`ifndef DEFS_DONE
	`define DEFS_DONE
	
	// (Fixed) FLASH COMMAND SET (For Memory_Interface and Memory_Model ) -- 
	`define PAGE_READ 'h00
	`define BEGIN_READ 'h90
	`define READ_ID 'h90
	`define RESET 'hFF
	`define PAGE_PROGRAM 'h80
	`define CONFIRM_PROGRAM 'h10
	`define BLOCK_ERASE 'h60
	`define BEGIN_ERASE 'hD0
	`define RANDOM_READ 'h85
	`define RANDOM_WRITE_1 'h05
	`define RANDOM_WRITE_2 'hE0
	`define READ_STATUS 'h70
	
	
	// (Flexible) MEMORY MODEL MACROS -- 
	//`define DEBUG_MEM_MODEL 1	
	`define MEM_DATA_WIDTH 8  								// x8 or x16 memory
	`define COMMAND_WIDTH 8									// Width of command register
	`define STATUS_REG_WIDTH 8								// Width of status register	
	`define COLUMN_WIDTH 2112								// Number of bytes per page(row)
	`define BLOCK_NUM 1024 									// Number of blocks
	`define BLOCK_LEN 64  									// Number of pages per block
	`define ROW_ADDR_WIDTH $clog2(`BLOCK_LEN*`BLOCK_NUM)	// Number of bits for storing page (row) address		
	`define COL_ADDR_WIDTH $clog2(`COLUMN_WIDTH)			// Number of bits for storing column address with the row
	`define MANUFACTURER_CODE 8'hEC							// From SAMSUNG K9F1G08R0A datasheet (for READ ID operation) 
	`define DEVICE_CODE 8'hA1								// From SAMSUNG K9F1G08R0A datasheet (for READ ID operation) 
	`define CYCLE_ID 8'h15 									// From SAMSUNG K9F1G08R0A datasheet (for READ ID operation) 
	
	
	// (Flexible) WISHBONE INTERFACE MACROS -- 
	
	`define WB_ADDR_WIDTH 12		// WISHBONE Address bus width
	`define WB_DATA_WIDTH 16		// WISHBONE Data bus width
	// Controller register addresses
	`define NFC_CMD		12'hF00
	`define ROW_ADDR 	12'hF02
	`define NFC_ERROR	12'hF03
	`define NFC_READY	12'hF04
	// (Fixed) command codes and command width for NFC (NAND Flash Controller)
	`define NFC_CMD_WIDTH  3
	`define NFC_RESET			3'b011
	`define NFC_BLOCK_ERASE		3'b100	
	`define NFC_PROGRAM_PAGE	3'b001
	`define NFC_READ_PAGE		3'b010
	`define NFC_READ_ID			3'b101

	
	// DUAL PORT BUFFER MACROS
	`define DEBUG_RAM
	`define BUF_ADDR_WIDTH 11
	`define BUF_DATA_WIDTH 8
	
`endif
	
	