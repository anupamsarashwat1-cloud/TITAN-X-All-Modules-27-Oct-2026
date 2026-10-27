import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_rv_bpu_basic(dut):
    """Test basic BTB update and prediction"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Init inputs
    dut.fetch_pc.value = 0
    dut.fetch_valid.value = 0
    dut.ex_pc.value = 0
    dut.ex_is_branch.value = 0
    dut.ex_is_jal.value = 0
    dut.ex_taken.value = 0
    dut.ex_target.value = 0
    dut.ex_valid.value = 0
    
    dut.rst_n.value = 0
    await Timer(22, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Fetch a PC (0x1000) that is not in BTB
    await FallingEdge(dut.clk)
    dut.fetch_pc.value = 0x1000
    dut.fetch_valid.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert dut.pred_valid.value == 0, "Prediction should be invalid (BTB miss)"
    
    # Now simulate execute stage resolving the branch at 0x1000 as TAKEN to 0x2000
    await FallingEdge(dut.clk)
    dut.fetch_valid.value = 0
    dut.ex_valid.value = 1
    dut.ex_pc.value = 0x1000
    dut.ex_is_branch.value = 1
    dut.ex_taken.value = 1
    dut.ex_target.value = 0x2000
    
    await RisingEdge(dut.clk)
    # BPU updates internally
    
    # Fetch 0x1000 again
    await FallingEdge(dut.clk)
    dut.ex_valid.value = 0
    dut.fetch_pc.value = 0x1000
    dut.fetch_valid.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    # BTB should hit, but counters are 2-bit saturating starting at 01 (weakly not-taken).
    # Wait, the local counter was 01, we took it once, so it becomes 10 (weakly taken).
    # So pred_taken should be 1!
    assert dut.pred_valid.value == 1, "Prediction should be valid (BTB hit)"
    assert dut.pred_target.value == 0x2000, "Target should be 0x2000"
    assert dut.pred_taken.value == 1, "Branch should be predicted taken"

def test_rv_bpu_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    
    runner = get_runner(sim)
    runner.build(
        sources=[os.path.join(proj_path, "frontend", "rv_bpu.v")],
        hdl_toplevel="rv_bpu",
        build_args=["-I" + os.path.join(proj_path, "common")],
        always=True,
    )
    runner.test(
        hdl_toplevel="rv_bpu",
        test_module="test_rv_bpu",
    )
