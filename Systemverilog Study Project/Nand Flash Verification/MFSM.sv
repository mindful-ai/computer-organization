/*Description of module:
--------------------------------------------------------------------------------
This module interprets commands from the Host, passes control to TFSM to execute 
repeating regular tasks with strict timing requirements.
--------------------------------------------------------------------
*/

`timescale 1 ns / 1 fs
module MFSM(
 input logic CLK,
 input logic RES,    
 input logic start,
 input logic [2:0] command,  
 input logic R_nB,         
 input logic BF_sel,       
 input logic io_0, 
 input logic t_done, 
 input logic tc8,         
 input logic tc4,// -- term counts fm Wait counter
   
 output logic setDone,
 output mBF_sel,
 output logic BF_we,       
 output logic t_start,      
 output logic [2:0] t_cmd,
 output logic WrECC,
 output logic EnEcc,
 output logic [1:0] AMX_sel,      
 output logic [7:0] cmd_reg,      
 output logic cmd_reg_we, 
 output logic RAR_we,
 output logic set835,       
 output logic cnt_res,      
 output logic wCntRes,      
 output logic wCntCE,//  -- wait conter ctrl
 output logic SetPrErr,     
 output logic SetErErr,     
 output logic [1:0] ADC_sel);// -- ad/dat/cmd mux ctrl
 
 enum logic [6:0]{Init,S_ADS, S_RAR, 
S_CmdL0,S_CmdL1,S_adL0,S_adL1, S_CmdL2, S_CmdL3,//-- EBL
S_WC0, S_WC1, S_wait, S_CmdL4, S_CmdL5, S_WC3, S_WC4, S_DR1, S_Done,
Sr_RAR, Sr_DnErr, Sr_CmdL0, Sr_CmdL1, Sr_AdL0, Sr_AdL1, Sr_AdL2,// -- RPA
Sr_AdL3, Sr_CmdL2, Sr_CmdL3, Sr_WC0, Sr_WC1, Sr_wait, Sr_RPA0,
Sr_CmdL4, Sr_CmdL5, Sr_AdL4, Sr_AdL5, Sr_CmdL6, Sr_CmdL7, Sr_WC2,Sr_RPA1,
Sr_wait1, Sr_wait2, Sr_WC3, Sr_Done,
Sw_RAR, Sw_CmdL0, Sw_CmdL1, Sw_AdL0, Sw_AdL1, Sw_AdL2, Sw_AdL3,Sw_WPA0,// -- WPA
Sw_CmdL2, Sw_CmdL3,  Sw_AdL4, Sw_AdL5, Sw_WPA1, 
Swait3, Sw_CmdL4, Sw_CmdL5, Sw_WC1, Sw_WC2, Sw_CmdL6,
Sw_CmdL7, Sw_DR1, Sw_Wait4, Sw_Wait5, Sw_done,
Srst_RAR, Srst_CmdL0, Srst_CmdL1,Srst_done,
Srid_RAR, Srid_CmdL0, Srid_CmdL1, Srid_AdL0,
Srid_Wait, Srid_DR1, Srid_DR2, Srid_DR3, Srid_DR4, Srid_done} NxST,CrST;

logic BF_sel_int;

parameter C0=4'b0000,
          C1=4'b0001,
          C3=4'b0011,
          C5=4'b0101,
          C6=4'b0110,
          C7=4'b0111,
          C8=4'b1000,
          CD=4'b1101,
          CE=4'b1110,
          CF=4'b1111,
          C9=4'b1001;
          
assign mBF_sel=BF_sel_int;// buff clock enable

always_ff@(posedge CLK)
 if(start)
  BF_sel_int<= 1'b1; // *** BF_sel;  
  
always_ff@(posedge CLK)
 CrST<=NxST;
 
//always@(RES or command or start or R_nB or TBF or RBF or t_done or tc4 or tc8 or io_0 or CrST)
always_comb
 if(RES) begin
  NxST <= Init;
  setDone <= 0;
//  ResTBF <= 1;
//  SetRBF <= 0;
  BF_we <= 0;
  t_start <= 0;
  t_cmd <= 3'b011; // nop
  WrECC <= 0;
  EnEcc <= 0;
  AMX_sel <= 2'b00;
  cmd_reg <= 8'b00000000;
  cmd_reg_we <= 0;
  set835 <= 0;
  cnt_res <= 0;
  wCntRes <= 0;
  wCntCE <= 0;
  ADC_sel <=2'b11;  // cmd to out
  SetPrErr <= 0;
  SetErErr <= 0;
  RAR_we <= 0;
  
end else begin           // default values
    setDone <= 0;
    BF_we <= 0;
    t_start <=0;
    t_cmd <= 3'b011; // nop
    WrECC <= 0;
    EnEcc <= 0;
    AMX_sel <= 2'b00;
    cmd_reg <= 8'b00000000;
    cmd_reg_we <= 0;
    set835 <= 0;
    cnt_res <= 0;
    wCntRes <= 0;
    wCntCE <= 0;
    ADC_sel <= 2'b11;
    SetPrErr <= 0;
    SetErErr <= 0;
//    SetBFerr <= 0;
    RAR_we <= 0; 

  unique case(CrST)
    Init:begin
      if (start)
        NxST <=S_ADS;
      else
        NxST <=Init;
    end
    S_ADS:begin
//      ADS <= 1;
      cnt_res <= 1;
      if (command ==3'b100) //EBL
        NxST <= S_RAR;
      else if (command==3'b010) //RPA
        NxST <= Sr_RAR;
      else if (command==3'b001) //WPA
        NxST <= Sw_RAR;
      else if (command==3'b011)
        NxST <= Srst_RAR; 
      else if (command==3'b101)
        NxST <= Srid_RAR;   
      else begin
        setDone <= 1;       // nop
        NxST <= Init;
        SetPrErr <=1;
        SetErErr <= 1;
      end
    end
    S_RAR:begin //          --EBL
      RAR_we <= 1;//--strobe the row address from the host
      NxST <= S_CmdL0;
    end
    S_CmdL0:begin
      cmd_reg <= {C6,C0};
      cmd_reg_we <= 1;
      NxST <= S_CmdL1;
    end
    S_CmdL1:begin
      t_start <= 1;
      t_cmd <= 3'b000; //-- cmd_latch
      if (t_done == 1)
        NxST <= S_adL0;
      else
        NxST <= S_CmdL1;
    end
    S_adL0:begin
      t_start <= 1;
      t_cmd <= 3'b001;// -- ad_latch
      ADC_sel <= 2'b10;// -- addr to out
      AMX_sel <= 2'b10;// -- ra1
      if (t_done == 1)
        NxST <= S_adL1;
      else
        NxST <= S_adL0;
    end
    S_adL1:begin
      t_start <=1;
      t_cmd <= 3'b001;// -- ad_latch
      ADC_sel <=2'b10;// -- addr to out      
      AMX_sel <=2'b11;// -- ra2
      if (t_done ==1)
        NxST <= S_CmdL2;
      else
        NxST <= S_adL1;
    end 
    S_CmdL2:begin
      cmd_reg <= {CD,C0};
      cmd_reg_we <= 1;
      NxST <= S_CmdL3;
    end
    S_CmdL3:begin
      t_start <= 1;
      t_cmd <=3'b000;// -- cmd_latch
      if (t_done ==1) 
        NxST <= S_WC0;
      else
        NxST <= S_CmdL3;
    end
    S_WC0:begin
      wCntRes <=1;
      NxST <= S_WC1;
    end
    S_WC1:begin
      wCntCE <=1;
      if (tc8 == 1)
        NxST <= S_wait;
      else
        NxST <= S_WC1;
    end
    S_wait:begin
      if (R_nB ==1)
        NxST <= S_CmdL4;
      else
        NxST <= S_wait;
    end 
    S_CmdL4:begin
      cmd_reg <= {C7,C0};
      cmd_reg_we <= 1;
      NxST <= S_CmdL5;
    end
    S_CmdL5:begin
      t_start <= 1;
      t_cmd <= 3'b000;// -- cmd_latch
      if (t_done ==1)
        NxST <= S_WC3;
      else
        NxST <= S_CmdL5;
    end
    S_WC3:begin
      wCntRes <= 1;
      NxST <= S_WC4;
    end
    S_WC4:begin
      wCntCE <=1;
      if (tc4 ==1)
        NxST <= S_DR1;
      else
        NxST <= S_WC4;
    end 
    S_DR1:begin
      t_start <= 1;
      t_cmd <= 3'b010;// -- data read 1 (status)
      if (t_done ==1)
        NxST <= S_Done;
      else
        NxST <= S_DR1;      
    end 
    S_Done:begin
      setDone <=1;
      NxST <= Init;
      if (io_0 == 1)
        SetErErr <= 1;
      else
        SetErErr <= 0;
    end    
    Sr_RAR:begin
      RAR_we <= 1;
  //    if (RBF==0)
        NxST <= Sr_CmdL0;
  //    else begin
  //      NxST <= Init;
  //      SetBFerr <=1;
  //      setDone <=1;
  //    end 
    end
    Sr_CmdL0:begin
      cmd_reg <= {C0,C0};
      cmd_reg_we <= 1;
      NxST <= Sr_CmdL1;
    end
    Sr_CmdL1:begin
      t_start <= 1;
      t_cmd <= 3'b000;// -- cmd_latch
      if (t_done ==1)
        NxST <= Sr_AdL0;
      else
        NxST <= Sr_CmdL1;
    end 
    Sr_AdL0:begin
      t_start <= 1;
      t_cmd <= 3'b001;// -- ad_latch
      ADC_sel <= 2'b10; //-- addr to out      
      AMX_sel <= 2'b00;// -- ca1
      if (t_done ==1)
        NxST <= Sr_AdL1;
      else
        NxST <= Sr_AdL0;
    end 
    Sr_AdL1:begin
      t_start <= 1;
      t_cmd <= 3'b001;// -- ad_latch
      ADC_sel <= 2'b10; //-- addr to out      
      AMX_sel <= 2'b01;// -- ca2
      if (t_done==1)
        NxST <= Sr_AdL2;
      else
        NxST <= Sr_AdL1;
    end
    Sr_AdL2:begin
      t_start <= 1;
      t_cmd <= 3'b001;// -- ad_latch
      ADC_sel <= 2'b10; //-- addr to out      
      AMX_sel <= 2'b10;// -- ra1
      if (t_done ==1)
        NxST <= Sr_AdL3;
      else
        NxST <= Sr_AdL2;
    end 
    Sr_AdL3:begin
      t_start <= 1;
      t_cmd <= 3'b001;// -- ad_latch
      ADC_sel <= 2'b10;// -- addr to out      
      AMX_sel <= 2'b11;// -- ra2
      if (t_done ==1)
        NxST <= Sr_CmdL2;
      else
        NxST <= Sr_AdL3;
    end
    Sr_CmdL2:begin
      cmd_reg <= {C3,C0};
      cmd_reg_we <= 1;
      NxST <= Sr_CmdL3;
    end
    Sr_CmdL3:begin
      t_start <= 1;
      t_cmd <= 3'b000;// -- cmd_latch
      if (t_done ==1)
        NxST <= Sr_WC0;
      else
        NxST <= Sr_CmdL3;
    end
    Sr_WC0:begin
      wCntRes <=1;
      NxST <= Sr_WC1;
    end
    Sr_WC1:begin
      wCntCE <= 1;
      if (tc8 ==1)
        NxST <= Sr_wait;
      else
        NxST <= Sr_WC1;
    end 
    Sr_wait:begin
      if (R_nB==0)
        NxST <= Sr_wait;
      else
        NxST <= Sr_RPA0;
    end 
    Sr_RPA0:begin
      t_start <= 1;
      t_cmd <= 3'b101; // data read w tc2048
      BF_we <= 1;
//      wCntCE <=1;    //wait no tRR
//      EnEcc <= 1;  //-- ecc ctrl
      if (t_done==1)begin
        NxST <= Sr_CmdL4;
        t_cmd <= 3'b000;
      end else
        NxST <= Sr_RPA0;
    end       
    Sr_CmdL4:begin
      cmd_reg <= {C0,C5};
      cmd_reg_we <= 1;
      set835 <= 1;
      t_cmd <= 3'b000;
      NxST <= Sr_CmdL5;
    end
    Sr_CmdL5:begin
      t_start <= 1;
      t_cmd <=3'b000; //-- cmd_latch
      if (t_done) 
        NxST <= Sr_AdL4;
      else
        NxST <= Sr_CmdL5;
    end
    Sr_AdL4:begin
      t_start <= 1;
      t_cmd <= 3'b001; //-- ad_latch
      ADC_sel <= 2'b10;// -- addr to out      
      AMX_sel <= 2'b00; //-- ca1
      if (t_done)
        NxST <= Sr_AdL5;
      else
        NxST <= Sr_AdL4;
    end 
    Sr_AdL5:begin
      t_start <= 1;
      t_cmd <= 3'b001;// -- ad_latch
      ADC_sel <=2'b10; //-- addr to out      
      AMX_sel <=2'b01; //-- ca2
      if (t_done)
        NxST <= Sr_CmdL6;
      else
        NxST <= Sr_AdL5;
    end     
    Sr_CmdL6:begin
      cmd_reg <= {CE,C0};
      cmd_reg_we <= 1;
      NxST <= Sr_CmdL7;
    end
    Sr_CmdL7:begin
      t_start <= 1;
      t_cmd <= 3'b000;// -- cmd_latch
      wCntRes <= 1; //-- sector sel count
//      byteSelCntRes <= 1;
      if (t_done)
        NxST <= Sr_RPA1;
      else
        NxST <= Sr_CmdL7;
    end 
    Sr_RPA1:begin
      t_start <= 1;
      t_cmd <=3'b100; //-- data read w tc3 (12 times - 835-840)
//      byteSelCntEn <= 1;
      WrECC <=1;
//      EnEcc <= 1;  //-- ecc ctrl
      if (t_done) begin 
        NxST <= Sr_wait1;
        t_cmd <= 3'b011;
      end else
        NxST <= Sr_RPA1;
   end 
    Sr_wait1:begin
      WrECC <=1;    
      NxST <= Sr_wait2;
    end
    Sr_wait2:begin
      WrECC <= 1;
      NxST <= Sr_WC3;
    end
    Sr_WC3:begin
      WrECC <=1;
      wCntCE <=1;
//      byteSelCntRes <=1;
      if (tc4 ==0)
        NxST <= Sr_WC3;
      else
        NxST <= Sr_Done;
    end 
    Sr_Done:begin
      setDone <=1;
//      SetRBF<=1;
      NxST <= Init;
    end
    Sw_RAR:begin      //-- WPA
      RAR_we <=1; //--strobe the row address from the host
   //   if (TBF==1)
        NxST <= Sw_CmdL0;
  //    else begin
  //      NxST <= Init;
  //      SetBFerr <=1;
  //      setDone <= 1;
  //    end
    end     
    Sw_CmdL0:begin
      cmd_reg <= {C8,C0};//--h80 to flash data out
      cmd_reg_we <= 1;
      NxST <= Sw_CmdL1;
    end
    Sw_CmdL1:begin
      t_start <=1;
      t_cmd <=3'b000;// -- cmd_latch
      if (t_done ==1)
        NxST <= Sw_AdL0;
      else
        NxST <= Sw_CmdL1;
    end       
    Sw_AdL0:begin
      t_start <= 1;
      t_cmd <= 3'b001;// -- ad_latch
      ADC_sel <= 2'b10; //-- addr to out      
      AMX_sel <= 2'b00;// -- ca1
      if (t_done ==1)
        NxST <= Sw_AdL1;
      else
        NxST <= Sw_AdL0;
    end
    Sw_AdL1:begin
      t_start <=1;
      t_cmd <=3'b001; //-- ad_latch
      ADC_sel <= 2'b10;// -- addr to out      
      AMX_sel <= 2'b01;// -- ca2
      if (t_done ==1)
        NxST <= Sw_AdL2;
      else
        NxST <= Sw_AdL1;
    end 
    Sw_AdL2:begin
      t_start <=1;
      t_cmd <= 3'b001;// -- ad_latch
      ADC_sel <= 2'b10; //-- addr to out      
      AMX_sel <= 2'b10;// -- ra1
      if (t_done ==1)
        NxST <= Sw_AdL3;
      else
        NxST <= Sw_AdL2;
    end
    Sw_AdL3:begin
      t_start<=1;
      t_cmd <= 3'b001;// -- ad_latch
      ADC_sel <= 2'b10; //- addr to out      
      AMX_sel <= 2'b11;// -- ra2
      if (t_done ==1)
        NxST <= Sw_WPA0;
      else
        NxST <= Sw_AdL3;
    end 
    Sw_WPA0:begin
      t_start <=1;
      t_cmd <= 3'b111;// -- data write w tc2048
//      wCntCE <= 1;
      ADC_sel <=2'b00;
//      EnEcc <=1;
      if (t_done==1) begin
        NxST <= Sw_CmdL2;
        t_cmd <=3'b000;
      end else
        NxST <= Sw_WPA0;
    end
    Sw_CmdL2:begin
      cmd_reg <= {C8,C5};
      cmd_reg_we <= 1;
      set835 <= 1;
      t_cmd <= 3'b000;
      NxST <= Sw_CmdL3;
    end
    Sw_CmdL3:begin
      t_start <= 1;
      t_cmd <= 3'b000; //-- cmd_latch
      if (t_done)
        NxST <= Sw_AdL4;
      else
        NxST <= Sw_CmdL3;
    end
    Sw_AdL4:begin
      t_start <= 1;
      t_cmd <= 3'b001; //-- ad_latch
      ADC_sel <= 2'b10; //-- addr to out      
      AMX_sel <= 2'b00;// -- ca1
      if (t_done)
        NxST <= Sw_AdL5;
      else
        NxST <= Sw_AdL4;
    end 
    Sw_AdL5:begin
      t_start <= 1;
      t_cmd <= 3'b001; //-- ad_latch
      ADC_sel <= 2'b10; //-- addr to out      
      AMX_sel <= 2'b01;// -- ca2
//      byteSelCntRes <= 1;      
      if (t_done)
        NxST <= Sw_WPA1;
      else
        NxST <= Sw_AdL5;
    end       
    Sw_WPA1:begin
      t_start <= 1;
      t_cmd <= 3'b110; //  -- data write w tc3
//      byteSelCntEn <= 1;
      ADC_sel <= 2'b01;//  -- ecc data to out
//      ecc2flash <= 1;
      EnEcc <= 1;  //-- ecc ctrl
      if (t_done) begin
        NxST <= Sw_CmdL4;
        t_cmd <= 3'b000;
      end else
        NxST <= Sw_WPA1;
    end 
    Sw_CmdL4:begin
      cmd_reg <= {C1,C0};
      t_cmd <= 3'b000;
      cmd_reg_we <= 1;
      NxST <= Sw_CmdL5;
    end
    Sw_CmdL5:begin
      t_start <= 1;
      t_cmd <= 3'b000; //-- cmd_latch
      if (t_done ==1)
        NxST <= Sw_WC1;
      else
        NxST <= Sw_CmdL5;
    end
    Sw_WC1:begin
      wCntRes <=1;
      NxST <= Sw_WC2;
    end
    Sw_WC2:begin
      wCntCE <=1;
      if (tc8 ==1)
        NxST <= Swait3;
      else
        NxST <= Sw_WC2;
    end
    Swait3:begin
      if (R_nB ==1)
        NxST <= Sw_CmdL6;
      else
        NxST <= Swait3;
    end
    Sw_CmdL6:begin
      cmd_reg <= {C7,C0};
      cmd_reg_we <= 1;
      NxST <= Sw_CmdL7;
    end
    Sw_CmdL7:begin
      t_start <=1;
      t_cmd <= 3'b000; //-- cmd_latch
      if (t_done ==1)
        NxST <= Sw_Wait4;
      else
        NxST <= Sw_CmdL7;
    end 
    Sw_Wait4:begin
      NxST <= Sw_Wait5;
    end
    Sw_Wait5:begin
      NxST <= Sw_DR1;
    end
    Sw_DR1:begin
      t_start <=1;
      t_cmd <= 3'b010;// -- read status
      if (t_done ==1)
        NxST <= Sw_done;
      else
        NxST <= Sw_DR1;
    end       
    Sw_done:begin
      setDone <= 1;
      NxST <= Init;
      if (io_0 ==1)
        SetPrErr <=1;
      else begin
        SetPrErr <= 0;
 //       ResTBF<= 1;
      end
    end 
    Srst_RAR:begin               
        NxST <= Srst_CmdL0;
    end     
    Srst_CmdL0:begin
      cmd_reg <= {CF,CF};//--hff to flash data out
      cmd_reg_we <= 1;
      NxST <= Srst_CmdL1;
    end
    Srst_CmdL1:begin
      t_start <=1;
      t_cmd <=3'b000;// -- cmd_latch
      if (t_done ==1)
        NxST <= Srst_done;
      else
        NxST <= Srst_CmdL1;
    end 
    Srst_done:begin
      setDone <= 1;
      NxST <= Init;
    end
    Srid_RAR:begin     
      RAR_we <=1; //--strobe the row address from the host
   //   if (TBF==1)
        NxST <= Srid_CmdL0;
  //    else begin
  //      NxST <= Init;
  //      SetBFerr <=1;
  //      setDone <= 1;
  //    end
    end     
    Srid_CmdL0:begin
      cmd_reg <= {C9,C0};//--h90 to flash data out
      cmd_reg_we <= 1;
      NxST <= Srid_CmdL1;
    end
    Srid_CmdL1:begin
      t_start <=1;
      t_cmd <=3'b000;// -- cmd_latch
      if (t_done ==1)
        NxST <= Srid_AdL0;
      else
        NxST <= Srid_CmdL1;
    end       
    Srid_AdL0:begin
      t_start <= 1;
      t_cmd <= 3'b001;// -- ad_latch
      ADC_sel <= 2'b10; //-- addr to out      
      AMX_sel <= 2'b10;// -- ra1
      if (t_done ==1)
        NxST <= Srid_Wait;
      else
        NxST <= Srid_AdL0;
    end
    Srid_Wait:begin
      wCntRes <=1;
      NxST <= Srid_DR1;
    end
    Srid_DR1:begin
      t_start <=1;
      t_cmd <= 3'b010;// -- read id
      BF_we <= 1;
      if (t_done ==1)
        NxST <= Srid_DR2;
      else
        NxST <= Srid_DR1;
    end   
    Srid_DR2:begin
      t_start <=1;
      t_cmd <= 3'b010;// -- read id
      BF_we <= 1;
      if (t_done ==1)
        NxST <= Srid_DR3;
      else
        NxST <= Srid_DR2;
    end       
    Srid_DR3:begin
      t_start <=1;
      t_cmd <= 3'b010;// -- read id
      BF_we <= 1;
      if (t_done ==1)
        NxST <= Srid_DR4;
      else
        NxST <= Srid_DR3;
    end       
    Srid_DR4:begin
      t_start <=1;
      t_cmd <= 3'b010;// -- read id
      BF_we <= 1;
      if (t_done ==1)
        NxST <= Srid_done;
      else
        NxST <= Srid_DR4;
    end               
    Srid_done:begin
      setDone <= 1;
      NxST <= Init;
    end 
  endcase
 end
endmodule    
