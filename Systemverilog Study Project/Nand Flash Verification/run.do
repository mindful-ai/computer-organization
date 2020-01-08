vlib work
vlog -mfcu ACounter.v Driver.sv DualPortRAM.sv ErrLoc.v H_gen.v MFSM.sv MemoryController.sv MemoryInterface.sv NFC_TOP.sv SystemTop.sv TFSM.sv WishboneFSM.sv WishboneInterface.sv MemoryStub.sv
vsim -novopt systest
run -all
