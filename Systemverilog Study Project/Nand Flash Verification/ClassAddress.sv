`include "Testpkg.sv"

class FlashAddress;
randc BlockAddr_t  BlockID;			// The block number inside Flash
	  BlockAddr_t PrevBlockID; 		

randc PageOffset_t PageOffset;		// The page within the block
	  PageOffset_t PrevPageOffset; 

randc ColAddr_t    ByteID; 			// The column address within the page
	  ColAddr_t PrevByteID; 		

bit sameBlockID, samePageOffset, sameByteID;

constraint c_ByteSpace {ByteID inside {[0:2047]};}; // Not testing ECC portion!

constraint c_BlockID 	{if (sameBlockID) BlockID == PrevBlockID;};
constraint c_PageOffset {if (samePageOffset) PageOffset == PrevPageOffset;};
constraint c_ByteID 	{if (sameByteID) ByteID == PrevByteID;};


function void post_randomize;
 PrevBlockID = BlockID;
 PrevByteID = ByteID;
 PrevPageOffset = PageOffset;
endfunction

function void print_address ();
$display($time, ": In %m, Address generated : Block = %0d, Page Offset = %0d, Byte = %0d", BlockID, PageOffset, ByteID);
endfunction

endclass