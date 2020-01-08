`include "definitions.sv"
`timescale 1 ns / 1 fs

module systest (); 		 		// System under test
parameter CLOCK_PERIOD = 16;    // Clock Period is fixed for the type of memory being targetted

bit clk;
logic reset;

// Clock Gen

always
begin
 #(CLOCK_PERIOD/2) clk = ~clk;
end


/*****************
Instantiate the system under test
******************/


wishbone HostIF (.clk_i (clk), .rst_i (reset));

HostStub Driver (HostIF.Master, clk, reset); // PROGRAM

NFC_TOP DUT (.HostIF (HostIF.Slave), .NandIF (NandIF.Controller)); 

NandFlashInterface NandIF (.SysReset(reset));

memory_stub Flash (.MemPort(NandIF.Memory), .ResetStub(reset));

endmodule