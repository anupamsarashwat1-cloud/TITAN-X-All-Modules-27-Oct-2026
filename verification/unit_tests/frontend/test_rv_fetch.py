import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_rv_fetch_reset(dut):
    """Test PC generation after reset"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Init inputs
    dut.stall.value = 0
    dut.flush.value = 0
    dut.branch_taken.value = 0
    dut.branch_target.value = 0
    dut.imem_arready.value = 0
    dut.imem_rdata.value = 0
    dut.imem_rvalid.value = 0
    dut.imem_rresp.value = 0
    
    # Assert reset
    dut.rst_n.value = 0
    await Timer(22, unit="ns") # past edge
    dut.rst_n.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    # After reset, fetch should request the reset PC
    # Wait one cycle for FSM to move from F_REQ to F_WAIT
    assert dut.imem_arvalid.value == 1, "Should assert ARVALID after reset"
    assert dut.imem_addr.value == 0x0000000000020000, "Should request from RESET_PC"
    
@cocotb.test()
async def test_rv_fetch_normal_fetch(dut):
    """Test a normal instruction fetch and PC increment"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.stall.value = 0
    dut.flush.value = 0
    dut.branch_taken.value = 0
    dut.branch_target.value = 0
    dut.imem_arready.value = 0
    dut.imem_rdata.value = 0
    dut.imem_rvalid.value = 0
    dut.imem_rresp.value = 0
    
    await Timer(22, unit="ns")
    dut.rst_n.value = 1
    
    await RisingEdge(dut.clk)
    
    # FSM moves to F_WAIT
    # Memory responds
    await FallingEdge(dut.clk)
    dut.imem_arready.value = 1
    await FallingEdge(dut.clk)
    dut.imem_arready.value = 0
    
    # Return instruction data
    dut.imem_rvalid.value = 1
    dut.imem_rdata.value = 0xDEADBEEF
    dut.imem_rresp.value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    # Next cycle, output should be valid and PC should increment
    assert dut.valid_out.value == 1, "Instruction should be valid"
    assert dut.instr_out.value == 0xDEADBEEF, "Instruction mismatch"
    assert dut.pc_out.value == 0x0000000000020000, "PC out mismatch"
    
    await FallingEdge(dut.clk)
    dut.imem_rvalid.value = 0
    
    # Next cycle it should request next PC
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert dut.imem_arvalid.value == 1, "Should request next instruction"
    assert dut.imem_addr.value == 0x0000000000020004, "PC should increment by 4"

@cocotb.test()
async def test_rv_fetch_branch(dut):
    """Test branch behavior"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.stall.value = 0
    dut.flush.value = 0
    dut.branch_taken.value = 0
    dut.branch_target.value = 0
    dut.imem_arready.value = 0
    dut.imem_rdata.value = 0
    dut.imem_rvalid.value = 0
    dut.imem_rresp.value = 0
    
    await Timer(22, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Force a branch
    await FallingEdge(dut.clk)
    dut.branch_taken.value = 1
    dut.branch_target.value = 0x80000000
    await FallingEdge(dut.clk)
    dut.branch_taken.value = 0
    
    # Wait for F_WAIT, then memory responds
    dut.imem_arready.value = 1
    await FallingEdge(dut.clk)
    dut.imem_arready.value = 0
    
    dut.imem_rvalid.value = 1
    dut.imem_rdata.value = 0x12345678
    dut.imem_rresp.value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.valid_out.value == 1, "Instruction should be valid"
    assert dut.instr_out.value == 0x12345678, "Instruction mismatch"
    assert dut.pc_out.value == 0x80000000, "Branch PC out mismatch"
    
    await FallingEdge(dut.clk)
    dut.imem_rvalid.value = 0
    
def test_rv_fetch_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    
    runner = get_runner(sim)
    runner.build(
        sources=[os.path.join(proj_path, "frontend", "rv_fetch.v")],
        hdl_toplevel="rv_fetch",
        build_args=["-I" + os.path.join(proj_path, "common")],
        always=True,
    )
    runner.test(
        hdl_toplevel="rv_fetch",
        test_module="test_rv_fetch",
    )
