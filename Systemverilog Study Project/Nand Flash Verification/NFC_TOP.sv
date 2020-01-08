`include "definitions.sv"

module NFC_TOP 
(
wishbone.Slave HostIF,
NandFlashInterface.Controller NandIF
);

logic CLK;
logic RES;

logic BF_sel;
logic [`BUF_ADDR_WIDTH-1:0]  BF_ad;
logic [`BUF_DATA_WIDTH-1:0]  BF_din;
logic [`BUF_DATA_WIDTH-1:0]  BF_dou;
logic 						 BF_we;
logic [`ROW_ADDR_WIDTH-1:0] RWA;

logic PErr;
logic EErr;
logic RErr;
  
logic [2:0] nfc_cmd;
logic nfc_strt;
logic nfc_done;
  
wb_slave WBcontrolFSM
(.*, .BF_dout(BF_dou), .page_address(RWA), .HostIF(HostIF)); 

memory_controller NANDController
(.*, .NandIF(NandIF));

endmodule
