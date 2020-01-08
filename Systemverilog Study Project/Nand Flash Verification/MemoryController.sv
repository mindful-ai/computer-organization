`timescale 1 ns / 1 fs
module memory_controller
(

//-- Flash mem i/f (Samsung 128Mx8)  
  NandFlashInterface NandIF,

//-- system
  input logic CLK,
  input logic RES,

//-- Host I/F
  input logic BF_sel ,
  input logic [10:0] BF_ad  ,
  input logic [7:0] BF_din ,
  output [7:0] BF_dou ,
  input logic BF_we  ,
  input logic [15:0] RWA    ,

//-- Status
  output logic PErr,
  output logic EErr,
  output logic RErr,

//-- control & handshake
  input logic [2:0] nfc_cmd ,
  input logic nfc_strt,
  output logic nfc_done
);


//-- NFC commands (all remaining encodings are ignored = NOP):
//-- WPA 001=write page
//-- RPA 010=read page
//-- EBL 100=erase block
//-- RET 011=reset
//-- RID 101= read ID


parameter HI= 1'b1;
parameter LO= 1'b0;

reg ires, res_t;
//
wire [7:0] FlashDataIn;
reg [7:0] FlashCmd;
reg [7:0] FlashDataOu;
wire [1:0] adc_sel;
wire [7:0] QA_1,QB_1;
wire [7:0] BF_data2flash, ECC_data;
wire Flash_BF_sel, Flash_BF_we, DIS, F_we;

//-- ColAd, RowAd
wire rar_we;
reg [7:0] addr_data;
reg [7:0] rad_1;
reg [7:0] rad_2;

wire [7:0] cad_1;
wire [7:0] cad_2;
wire [1:0] amx_sel;
//-- counter ctrls
wire CntEn, tc3, tc2048, cnt_res, acnt_res;
wire [11:0] CntOut;
//--TFSM
reg DOS;  //-- data out strobe
wire t_start, t_done;
wire [2:0] t_cmd;
wire WCountRes, WCountCE;
reg TC4, TC8;  //-- term counts

wire cmd_we ;
wire [7:0] cmd_reg;
wire SetPrErr, SetErErr,SetRrErr;
//--
wire WrECC, WrECC_e, enEcc, Ecc_en,ecc_en_tfsm;
wire setDone, set835;

//-- internal sigs before the out registers
wire ALE_i, CLE_i, WE_ni, CE_ni, RE_ni;
wire DOS_i;
reg [7:0] FlashDataOu_i ; 


assign BF_dou =  QA_1;
assign BF_data2flash = QB_1;                                                     
assign cad_1 = CntOut[7:0];
assign cad_2 = {4'b0000,CntOut[11:8]};

assign acnt_res = (ires | cnt_res);
assign WrECC_e = WrECC & DIS;
assign Flash_BF_we = DIS & F_we;

assign Ecc_en = enEcc & ecc_en_tfsm;


ebr_buffer buff( 
          .data_a(BF_din),
          .OutA(QA_1),
          .addr_a(BF_ad),
          .clk(CLK),
          .clk_en_a(BF_sel),
          .we_a(BF_we),
          .reset_a(LO),
          .data_b(FlashDataIn),
          .OutB(QB_1),
          .addr_b(CntOut[10:0]),
          //.ClockB(CLK),
          .clk_en_b(Flash_BF_sel),
          .we_b(Flash_BF_we),
          .reset_b(LO)
);

ACounter addr_counter (
          .clk(CLK),
          .Res(acnt_res),
          .Set835(set835),
          .CntEn(CntEn),
          .CntOut(CntOut),
          .TC2048(tc2048),
          .TC3(tc3)
);
          
TFSM tim_fsm(
          .CLE(CLE_i),
          .ALE (ALE_i),
          .WE_n(WE_ni),
          .RE_n(RE_ni),
          .CE_n(CE_ni),
          .DOS (DOS_i),
          .DIS (DIS),
          .cnt_en(CntEn),
          .TC3(tc3),
          .TC2048(tc2048),
          .CLK(CLK),
          .RES(ires),
          .start(t_start),
          .cmd_code(t_cmd),
          .ecc_en(ecc_en_tfsm),
          .Done(t_done)
);
          
MFSM main_fsm
(
  .CLK ( CLK ),
  .RES ( ires ),
  .start ( nfc_strt),
  .command(nfc_cmd),
  .setDone(setDone),
  .R_nB (NandIF.R_nB),
  .BF_sel( BF_sel),
  .mBF_sel ( Flash_BF_sel),
  .BF_we( F_we),
  .io_0( FlashDataIn[0]),
  .t_start ( t_start),
  .t_cmd  ( t_cmd),
  .t_done ( t_done),
  .WrECC ( WrECC),
  .EnEcc ( enEcc),
  .AMX_sel ( amx_sel),
  .cmd_reg ( cmd_reg),
  .cmd_reg_we( cmd_we),
  .RAR_we ( rar_we),
  .set835 ( set835),
  .cnt_res ( cnt_res),
  .tc8  ( TC8), 
  .tc4  ( TC4),
  .wCntRes( WCountRes), 
  .wCntCE ( WCountCE),
  .SetPrErr  ( SetPrErr), 
  .SetErErr  (  SetErErr),
  .ADC_sel ( adc_sel)
);
  
H_gen ecc_gen(
     . clk( CLK),
     . Res( acnt_res),
     . Din( BF_data2flash[3:0]),
     . EN (Ecc_en),
      
     . eccByte ( ECC_data)
);
      
ErrLoc ecc_err_loc 
 (
      .clk( CLK),
      .Res (acnt_res),
      .F_ecc_data (FlashDataIn[6:0]),
      .WrECC (WrECC_e),
            
      .ECC_status (SetRrErr)      
);        

always_ff @(posedge CLK)
begin
  res_t <= RES;
  ires <= res_t;
end

always_ff @(posedge CLK)
  if (rar_we) begin
    rad_1=RWA[7:0];
    rad_2=RWA[15:8];
  end

always_ff @(posedge CLK)
begin
  FlashDataOu <= FlashDataOu_i;
  DOS <= DOS_i;
  NandIF.ALE <= ALE_i;
  NandIF.CLE <= CLE_i;
  NandIF.WE_n <= WE_ni;
  NandIF.CE_n <= CE_ni;
  NandIF.RE_n <= RE_ni;
end

  
always_comb
 begin
  case (amx_sel)
     2'b11 : addr_data <= rad_2;
     2'b10 : addr_data <= rad_1;
     2'b01 : addr_data <= cad_2;
     default: addr_data <= cad_1;
  endcase
 end

always_comb
begin
case (adc_sel)
   2'b11 : FlashDataOu_i <= FlashCmd;
   2'b10 : FlashDataOu_i <= addr_data;
   2'b01 : FlashDataOu_i <= ECC_data;
   default: FlashDataOu_i <= BF_data2flash;
endcase
end

reg [3:0] WC_tmp;

always_ff @(posedge CLK)
begin
  if ((ires ==1'b1) | (WCountRes ==1'b1))
    WC_tmp<= 4'b0000;
  else if (WCountCE ==1'b1)
    WC_tmp<= WC_tmp + 1;

  
  if (WC_tmp ==4'b0100) begin
    TC4 <= 1'b1; 
    TC8 <= 1'b0;
  end else if (WC_tmp ==4'b1000) begin
    TC8<= 1'b1; 
    TC4 <=1'b0;
  end else begin
    TC4 <=1'b0;
    TC8 <=1'b0;
  end
//  WCountOut <= WC_tmp;
end


always_ff @(posedge CLK)
begin
  if (ires)
    FlashCmd <=8'b00000000;
  else if (cmd_we)
    FlashCmd <= cmd_reg;
end

always_ff @(posedge CLK)
begin
  if (ires)
    nfc_done <= 1'b0;
  else if (setDone) 
    nfc_done <=1'b1;
  else if (nfc_strt) 
    nfc_done <=1'b0;
 
end


always_ff @(posedge CLK)
begin
  if (ires)
    PErr <=1'b0;
  else if (SetPrErr)
    PErr <= 1'b1;
  else if (nfc_strt)
    PErr <= 1'b0;
end

always_ff @(posedge CLK)
begin
  if (ires)
    EErr <=1'b0;
  else if (SetErErr)
    EErr <=1'b1;
  else if (nfc_strt)
    EErr <= 1'b0;
end

always_ff @ (posedge CLK)
begin
  if (ires)
    RErr <=1'b0;
  else if (SetRrErr)
    RErr <= 1'b1;
  else if (nfc_strt)
    RErr <= 1'b0;
end


assign FlashDataIn = NandIF.DIO;
assign NandIF.DIO =(DOS == 1'b1)?FlashDataOu:8'hzz;


endmodule
