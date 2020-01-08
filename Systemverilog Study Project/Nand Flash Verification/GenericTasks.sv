/*********************************************/

task FillBuffer (output BufData_t TxData[$]); // Fills the buffer in controller with random data
BufData_t Data;
for (int j=0; j<BufferLen; j++)
begin
TxData[j] =  $urandom();
Drive.WriteBuffer (j, TxData[j]);	
end
endtask

/*********************************************/

task FetchBuffer (output BufData_t RxData[$]); // Fills the buffer in controller with random data
for (int j=0; j<BufferLen; j++)
begin
Drive.ReadBuffer (j, RxData[j]);	
end
endtask

/********************************************/

task DisplayObjective(input string Objective); 
$display ($time, ": ******* New Test Objective: %s *******", Objective);
endtask

/********************************************/

task DisplayErrors(input int Errors);
$display ($time, ": ******** Test completed with %0d Errors ******* \n \n \n", Errors);
if (Errors!==0) 
begin
	TestsFailed++;
end
endtask

/********************************************/

