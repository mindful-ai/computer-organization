`include "definitions.sv"


module wb_slave
(
// Wishbone slave interface
wishbone.Slave HostIF,

// System signals
output logic CLK, RES,

// Error inputs
input PErr, RErr, EErr,

// Controller protocol signals
input  logic nfc_done,
output logic nfc_strt,

// Dual port RAM signals
input 	[`BUF_DATA_WIDTH-1:0] BF_dout,
output	[`BUF_DATA_WIDTH-1:0] BF_din,
output 	[`BUF_ADDR_WIDTH-1:0] BF_ad,
output 						  BF_we, BF_sel,

// Arguments for Flash operation
output [`ROW_ADDR_WIDTH-1:0] page_address,   	// Page address (connects to rwa of controller)
output [`NFC_CMD_WIDTH-1:0]  nfc_cmd			// Command
);



/******* Controller register set and their clock enables ***********/

//logic 						BF_sel_q;    		 			// (Read/Write) Host buffer-enable 

logic [2:0] 				 nfc_cmd_q;  		 			// (Write-Only)NAND Flash Controller command 
logic [`ROW_ADDR_WIDTH-1:0] page_address_q;   				// (Write-Only)Row address for Flash operation
logic [2:0]					 nfc_error_q, nfc_error_next;	// (Read-Only) NAND Flash Controller error signals {Page, Erase, ECC} 
logic 						 nfc_ready_q, nfc_ready_next;    // (Read-Only) Controller ready/busy signal


/**** Other output assignments *****/
assign CLK = HostIF.clk_i;
assign RES = HostIF.rst_i;
assign page_address = page_address_q;
assign nfc_cmd = nfc_cmd_q;


/**** Control FSM variable type definition****/
typedef enum logic [1:0] {idle, gen_start, wait_done} FSMstate;
FSMstate state, nextState;


/***** WISHBONE cycle acknowledge and termination ****/
logic ack_internal, ack_internal_q;

assign ack_internal = HostIF.wb_stb & HostIF.wb_cyc;  
assign HostIF.wb_ack = ack_internal_q;


always_ff @ (posedge HostIF.clk_i, posedge HostIF.rst_i)
begin
	if (HostIF.rst_i)
		ack_internal_q <= 1'b0;
		
	else if (ack_internal_q)   // Put acknowledge down after one cycle (higher priority)
		ack_internal_q <= 1'b0;
		
	else if (ack_internal)
		ack_internal_q <= 1'b1;  // Register the internal acknowledge signal (lower priority)
	
	else 
		ack_internal_q <= ack_internal_q; // Retain state
end


/*** Identify WISHBONE read or write transaction ***/ 
logic wr_txn, rd_txn;
assign wr_txn = (HostIF.rst_i) ? 1'b0 :  HostIF.wb_we && HostIF.wb_stb && HostIF.wb_cyc;
assign rd_txn = (HostIF.rst_i) ? 1'b0 :  !HostIF.wb_we && HostIF.wb_stb && HostIF.wb_cyc;


/****DPRAM (buffer) control signals ******/
logic target_buffer;
assign target_buffer = (HostIF.wb_addr <= (2**`BUF_ADDR_WIDTH)-1) ? 1'b1: 1'b0;  // Identify if master is targetting DPRAM

assign BF_din = HostIF.wb_data_i_s [`BUF_DATA_WIDTH-1:0];
assign BF_ad =  HostIF.wb_addr [`BUF_ADDR_WIDTH-1:0];
assign BF_we =  wr_txn; // target and ack signals moved to bf-sel logic
assign BF_sel = (target_buffer) && (!ack_internal_q) && (rd_txn || wr_txn);
// assign BF_sel = BF_sel_q && (target_buffer) && (!ack_internal_q);


/**** Synchronous logic to update the memory-mapped register set of controller ****/

logic [`WB_DATA_WIDTH-1:0] data_out;


always_ff @ (posedge HostIF.clk_i, posedge HostIF.rst_i)
begin
if (HostIF.rst_i)
begin
	//BF_sel_q <= 1'b0;
	nfc_cmd_q <= 3'b111;
	page_address_q <= '0;
end

else if (wr_txn && !ack_internal_q) // WISHBONE master write transaction 
begin
	case (HostIF.wb_addr)
	`NFC_CMD	: nfc_cmd_q <= HostIF.wb_data_i_s [`NFC_CMD_WIDTH-1:0];
	//`BUFFER_SEL	: BF_sel_q <= HostIF.wb_data_i_s;
	`ROW_ADDR	: page_address_q <= HostIF.wb_data_i_s[`ROW_ADDR_WIDTH-1:0];
	endcase
end


else if (rd_txn && !ack_internal_q) // WISHBONE master read transaction // needs a registered ack signal which goes up accoording to stb and goes down 1 cycle later  
begin

		case (HostIF.wb_addr)
		//`NFC_CMD	: data_out <= nfc_cmd_q;
		//`BUFFER_SEL	: data_out <= BF_sel_q;
		//`ROW_ADDR	: data_out <= page_address_q;
		`NFC_ERROR	: data_out <= nfc_error_q;
		`NFC_READY	: data_out <= nfc_ready_q;
		default		: data_out <= data_out;
		endcase
end
end

assign HostIF.wb_data_o_s = (target_buffer) ? BF_dout : data_out; // Slave output for a master read WISHBONE transaction


/****** Control FSM to start and monitor NAND flash controller operation ******/

// Synchronous logic
always_ff @ (posedge HostIF.clk_i)
begin
if (HostIF.rst_i)
	begin
	state <= idle;
	nfc_error_q <= '0;
	nfc_ready_q <= 1'b1;
	end
else
	begin
	state <= nextState;
	nfc_error_q <= nfc_error_next;
	nfc_ready_q <= nfc_ready_next;
	end
end


// Combinatorial next-state logic and Moore outputs
always_comb
begin
// default values to avoid latch
nextState = state;
nfc_strt = 1'b0;
nfc_ready_next = nfc_ready_q;
nfc_error_next = nfc_error_q;

unique case (state)
idle: begin
		if (wr_txn && (HostIF.wb_addr == `NFC_CMD))  // If host writes to the command register 
		begin
			nfc_ready_next = 1'b0;
			nextState = gen_start;
		end
	  end
	
gen_start: begin
			nfc_strt = 1'b1;
			nextState = wait_done;
		   end
		   
wait_done: begin
			nfc_strt = 1'b0;
			if (nfc_done) 
			begin
				nfc_ready_next = 1'b1;
				nfc_error_next = {PErr, EErr, RErr};
				nextState = idle;
			end
			else
			begin
				nextState = wait_done; // Explicit wait on the current state
			end
		   end
		   
endcase
end

endmodule