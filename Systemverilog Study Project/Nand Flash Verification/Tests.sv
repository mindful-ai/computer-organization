/*********************************************/

task Test_EraseBlock(input int NUMTEST = 2, PageIterations = 10);
int Errors;
string Objective; 
BufData_t TxData [$], RxData [$];
MemRowAddr_t Page;
FlashAddress FA;
Objective= "Test case to check if erase works";
DisplayObjective (Objective);

while (NUMTEST)
begin
	FA = new();
	assert (FA.randomize());
	FA.print_address();
	FillBuffer (TxData);
	Drive.ProgramFlashPage ({FA.BlockID, FA.PageOffset});
	Drive.EraseFlashBlock({FA.BlockID, FA.PageOffset}); // Page offset should be ignored
	for (int i=0; i<PageIterations; i++)
	begin
		Drive.ReadFlashPage({FA.BlockID, FA.PageOffset});
		FA.sameBlockID = 1; // Get new page within the same block
		assert (FA.randomize());
		FA.print_address();
		FetchBuffer (RxData);
		foreach(RxData[i])
		if (RxData[i] !== '1)
		begin
			Errors++;
		end
	end
NUMTEST--;
end
DisplayErrors(Errors);	
endtask

/*********************************************/

task Test_ReadFlashPage(int NUMTEST = 5);
string Objective;
int Errors, BadIndex;
BufData_t TxData[$], RandData[$], RxData[$];
FlashAddress FA; 
Objective = "Testcase to verify Read Flash Page operation works";
FA = new();
DisplayObjective (Objective);
while (NUMTEST)
begin
	assert(FA.randomize());
	FA.print_address();
	FillBuffer(TxData);
	Drive.ProgramFlashPage({FA.BlockID, FA.PageOffset});
	FillBuffer(RandData);
	Drive.ReadFlashPage({FA.BlockID, FA.PageOffset});
	FetchBuffer(RxData);

	for (int i=0; i<TxData.size(); i++)
	begin
		if (TxData !== RxData)
			BadIndex++;
	end
	
	if (BadIndex) 
	begin
		Errors++;
	end
	
	NUMTEST--;
end
DisplayErrors(Errors);
endtask

/********************************************/


task Test_RWbuffer (input int NUMTEST = 5);
// Description
// Writes random data to 'NUMTEST' randomized locations within the Dual Port Buffer and reads it back
string Objective;
int Errors;
BufData_t  TxData, RxData, TxDQ [$]; // Queue of buffer data
BufAddress_t   Address, AQ [$]; // Queue of buffer addresses

Objective = "Testcase to verify randomized writes followed by reads to the Dual-Port buffer";
DisplayObjective(Objective);

for (int i=0; i<NUMTEST; i++)
begin
	TxData = $urandom;	
	Address = $urandom_range (2047);
	TxDQ.push_back(TxData);
	AQ.push_back (Address);
	Drive.WriteBuffer (Address, TxData); // Processor task
end
for (int i=0; i<NUMTEST; i++)
begin
	Address = AQ.pop_front;
	Drive.ReadBuffer (Address, RxData); // Processor task
	TxData = TxDQ.pop_front();
	if (RxData !== TxData)
	begin
		Errors++;
		$display ($time, ": Test failing for address = %0d, Data Sent = %0d, Data Received = %0d", Address, TxData, RxData);
	end
end	
DisplayErrors (Errors);
endtask


/*********************************************/

// Description: 
// Performs the PROGRAM operation on 'NUMTESTS" random Page Addresses of Flash with randomized data
// and then probes into the memory to see if data has been successfully programmed

task Test_ProgramFlashPage(int NUMTEST = 5);
string Objective;


int Errors;

BufData_t TxData [BufAddress_t][int];
MemData_t RxData [ColAddr_t][int]; // Associative array of memory data indexed by memory column address
MemRowAddr_t TxRow [];

Objective = "Testcase to verify that ProgramPage operation works";

DisplayObjective(Objective);

TxRow = new [NUMTEST];

for (int i=0; i<NUMTEST; i++)
begin	
	TxRow[i] = $urandom_range (`BLOCK_LEN*`BLOCK_NUM);
	for (int j =0; j < BufferLen; j++)	
	begin
		TxData [j][i] = $urandom;
		Drive.WriteBuffer (j, TxData [j][i]); // Processor task
	end
	Drive.ProgramFlashPage (TxRow[i]); // Processor task
end

for (int i=0; i<NUMTEST; i++)
begin
	for (int j =0; j < BufferLen; j++)	
	begin
	RxData[j][i] = $root.systest.Flash.MemArray[TxRow[i]][j]; // Probe into the memory_stub to see if the data has correctly been programmed into memory
	if (RxData[j][i] !== TxData[j][i])
	begin
		Errors++;
		$display ($time, ": Test Failing for row = %0d, column = %0d", i,j);
	end
	end
end
DisplayErrors(Errors);
endtask

/*********************************************/
task Test_ReadFlashID ();
int Errors;
string Objective;
logic [3:0][`BUF_DATA_WIDTH-1:0] FlashID;

Objective = "Test if Flash is returning the ID from the datasheet and display it";  

DisplayObjective(Objective);
Drive.ReadFlashID(FlashID);
if (FlashID !== {`CYCLE_ID, 8'h00, `DEVICE_CODE, `MANUFACTURER_CODE}) 
	Errors++;
$display ($time, ": Flash ID = %h", FlashID);
DisplayErrors(Errors);
endtask
/*********************************************/


/*********************************************/

task Test_GetSetByte();
int Errors;
string Objective;
logic [7:0] TxByte, RxByte, RandByte;
int Addr;

Objective = "Test case to check if Set byte and get byte work";
DisplayObjective(Objective);

TxByte = $urandom(0);
Addr = $urandom_range (`BLOCK_LEN*`BLOCK_NUM);
Drive.SetFlashByte (Addr, TxByte);
RandByte = $urandom(1); 
Drive.WriteBuffer (Addr, RandByte); // Change the data on buffer location which was written (to ensure everything works correctly)
Drive.GetFlashByte (Addr, RxByte);
if (RxByte !== TxByte) 
begin
	Errors++;
	$display ($time, ": Error, Byte Sent = %0d, Byte received = %0d", TxByte, RxByte);
end

else $display ($time, ": Success, Byte Sent = %0d, Byte received = %0d", TxByte, RxByte);

DisplayErrors(Errors);
endtask
/*********************************************/

task Test_ResetFlash();
string Objective;
Objective = "Testcase to verify Reset Page operation works";
DisplayObjective (Objective);
Drive.ResetFlash();
$display ($time, ": Reset Complete");
endtask
