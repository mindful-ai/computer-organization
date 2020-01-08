/* Description of module:
--------------------------------------------------------------------------------
 Timing FSM creating all the necessary control signals for the nand-flash memory.
 --------------------------------------------------------------------
*/

`timescale 1 ns / 1 fs

module TFSM(
  output logic CLE, //-- CLE               
  output logic ALE, //-- ALE               
  output logic WE_n, // -- ~WE              
  output logic RE_n, // -- ~RE              
  output logic CE_n, // -- ~CE              
  output logic DOS, // -- data out strobe  
  output logic DIS, //  -- data in strobe  
  output logic cnt_en, //-- ca counter ce   
  input logic TC3, //-- term counts         
  input logic TC2048,                     
  input logic CLK,                        
  input logic RES,                        
  input logic start,                       
  input logic [2:0] cmd_code, 
  output logic Done,                  
  output logic ecc_en);

// Command codes:
// 000 -Cmd Latch
// 001 -Addr latch
// 010 -Data Read 1 (1 cycle as status)
// 100 -Data Read multiple (w TC3)
// 101 -Data Read multiple (w TC2048)
// 110 -Data Write (w TC3)
// 111 -Data Write (w TC2048)
// others'll return to Init

enum logic [4:0] {Init, S_Start, S_CE, 
S_CLE, S_CmdOut, S_WaitCmd, DoneCmd, Finish, // Cmd latch
S_ALE, S_ADout, WaitAd, DoneAd, // Addr latch
S_RE1, WaitR1, WaitR2, DoneR1,// -- Read data 1
S_RE, WaitR1m, WaitR2m, WaitR3m, S_DIS, FinishR,//  -- Read data TC
S_WE, WaitW, WaitW1, WaitW2, S_nWE, FinishW} NxST, CrST;//   -- write data

logic Done_i;//  -- muxed Term Cnt
wire TC;
logic [2:0] cmd_code_int;

assign TC = cmd_code_int[0]?TC2048:TC3;

always_ff@(posedge CLK)
  if (RES)
    Done <=0;
  else
    Done <= Done_i;


always_ff@(posedge CLK)
  cmd_code_int <= cmd_code;

//the State Machine
always_ff@(posedge CLK)
  CrST <= NxST;


always_comb
if (RES) begin
  NxST <= Init;
  DIS <= 0;
  DOS <= 0;
  Done_i <=0;
  ALE <= 0;
  CLE <= 0;
  WE_n <= 1;
  RE_n <= 1;
  CE_n <= 1;
  cnt_en <=0;
  ecc_en<=1'b0;
end else begin//            -- default values
   DIS <= 0;
   DOS <= 0;
   Done_i <=0;
   ALE <= 0;
   CLE <= 0;
   WE_n <= 1;
   RE_n <= 1;
   CE_n <= 1;
   cnt_en <=0;
   ecc_en<=1'b0;
  case (CrST)
    Init:begin
      if (start)
        NxST <= S_Start;
      else
        NxST <= Init;
    end
    S_Start:begin
      if (cmd_code_int==3'b011)//  -- nop
        NxST <= Init;
      else
        NxST <= S_CE;
    end
    S_CE:begin
      if (cmd_code_int==3'b000) begin
        NxST <= S_CLE;
        CE_n <= 0;
      end else if (cmd_code_int ==3'b001) begin
        NxST <= S_ALE;
        CE_n <= 0;        
      end else if (cmd_code_int ==3'b010) begin
        NxST <= S_RE1;
        CE_n <= 0;        
      end else if (cmd_code_int[2:1]==2'b10) begin
        NxST <= S_RE;
        CE_n <= 0;        
      end else if (cmd_code_int[2:1] ==2'b11) begin
        NxST <= S_WE;
        CE_n <= 0;        
      end else
        NxST <= Init;
    end 
    S_CLE:begin
      CE_n <=0;
      CLE <= 1;
      WE_n <=0;
      NxST <= S_CmdOut;
    end
    S_CmdOut:begin
      CE_n <=0;
      CLE <= 1;
      WE_n <= 0;
      DOS <= 1;
      NxST <= S_WaitCmd;
    end
    S_WaitCmd:begin
      CE_n <=0;
      CLE <= 1;
      WE_n <=0;
      DOS <= 1;
      NxST <= DoneCmd;
    end
    DoneCmd:begin
      Done_i <=1;      
      CE_n <= 0;
      CLE <= 1;
      DOS <= 1;
      NxST <= Finish;
    end  
    Finish:begin
      DIS <=1; // --1226
      if (start)
        NxST <= S_Start;
      else
        NxST <= Init;
    end
    S_ALE:begin
      CE_n <=0;
      ALE <= 1;
      WE_n <= 0;
      NxST <= S_ADout;
    end
    S_ADout:begin
      CE_n <= 0;
      ALE <= 1;
      WE_n <= 0;
      DOS <= 1;
      NxST <= WaitAd;
    end
    WaitAd:begin
      CE_n <= 0;
      ALE <= 1;
      WE_n <= 0;
      DOS <= 1;
      NxST <= DoneAd;
    end
    DoneAd:begin
      Done_i <= 1;
      CE_n <= 0;
      ALE <= 1;
      DOS <= 1;
      NxST <= Finish;
    end
    S_RE1:begin
      CE_n <= 0;
      RE_n <= 0;
      NxST <= WaitR1;
    end
    WaitR1:begin
      CE_n <= 0;
      RE_n <= 0;
      NxST <= WaitR2;
    end
    WaitR2:begin
      CE_n <= 0;
      RE_n <= 0;
      NxST <= DoneR1;
    end
    DoneR1:begin
      Done_i <= 1; 
      cnt_en <=1;   
      NxST <= Finish; // -- can set DIS there as there'll be no F_we in EBL case
    end  
    S_RE:begin
      CE_n <= 0;
      RE_n <= 0;
      NxST <= WaitR1m;
    end
    WaitR1m:begin
      CE_n <= 0;
      RE_n <= 0;
      NxST <= WaitR2m;
    end
    WaitR2m:begin
      CE_n <= 0;
      RE_n <= 0;
      NxST <= S_DIS;
    end
    S_DIS:begin
      CE_n <=0;
//--    DIS  <=1;
      if (TC ==0)
        NxST <= WaitR3m;
      else
        NxST <= FinishR;
    end
    WaitR3m:begin
      CE_n <=0;
      cnt_en <=1;
      DIS <=1; // --1226
      NxST <= S_RE;
    end
    FinishR:begin
      Done_i <=1;
      cnt_en <=1;  //--AY
      DIS <=1; //    --1226
      if (start)
        NxST <= S_Start;
      else
        NxST <= Init;
    end 
    S_WE:begin
      CE_n <=0;
      WE_n <=0;
      DOS <=1;
      NxST <= WaitW;
    end
    WaitW:begin
      ecc_en<=1'b1;
      CE_n <=0;
      WE_n <= 0;
      DOS <= 1;
      NxST <= WaitW1;
    end
    WaitW1:begin
      CE_n <=0;
      WE_n <=0;
      DOS <=1;
      NxST <= S_nWE;
    end
    S_nWE:begin
      CE_n <=0;
      DOS <= 1;
      if (TC ==0)
        NxST <= WaitW2;
      else
        NxST <= FinishW;
    end 
    WaitW2:begin
      CE_n <= 0;
      DOS <= 1;    
      cnt_en <= 1;
      NxST <= S_WE;
    end
    FinishW:begin
      Done_i <= 1;
      cnt_en <= 1;//  --AY
      DOS <= 1; //    --AY driving data for ECC
      if (start)
        NxST <= S_Start;
      else
        NxST <= Init;
    end 
  endcase
 end


endmodule

