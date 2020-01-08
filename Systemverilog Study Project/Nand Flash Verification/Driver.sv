`include "definitions.sv"
`include "Testpkg.sv"
`include "ClassAddress.sv"

program HostStub (interface Drive, input logic clk, output logic reset);
int TestsFailed;

`include "GenericTasks.sv"
`include "Tests.sv"

initial 
begin
SystemReset;
ApplyTest();
$stop();
end

task SystemReset ();
reset=1'b1;
repeat(3) 
begin
@ (posedge clk);
end
reset = 1'b0;
@(posedge clk);
endtask


/******************
Apply the tests required
******************/
task ApplyTest ();
	Test_RWbuffer(1);
	Test_ProgramFlashPage(1);
	Test_ReadFlashID();
	Test_EraseBlock();
	Test_GetSetByte();
	Test_ResetFlash();
	Test_ReadFlashPage();
	$display($time, ": ******* End of simulation, Tests Failed = %0d ******* \n", TestsFailed);
endtask


endprogram
