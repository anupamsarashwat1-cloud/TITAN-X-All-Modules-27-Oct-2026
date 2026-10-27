import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_reset_sync_basic(dut):
    """Test basic reset deassertion synchronization"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Assert reset asynchronously
    dut.async_rst_n.value = 0
    await Timer(12, unit="ns")
    
    assert dut.sync_rst_n.value == 0, "Sync reset should be asserted immediately"
    
    # Deassert reset asynchronously
    dut.async_rst_n.value = 1
    
    # Should stay asserted for STAGES cycles (default 2)
    await RisingEdge(dut.clk)
    assert dut.sync_rst_n.value == 0, "Sync reset should still be asserted (stage 1)"
    
    await RisingEdge(dut.clk)
    # Output may update on edge depending on simulation delta, wait one more
    await RisingEdge(dut.clk)
    assert dut.sync_rst_n.value == 1, "Sync reset should be deasserted after 2 cycles"
    
def test_reset_sync_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    
    runner = get_runner(sim)
    runner.build(
        sources=[os.path.join(proj_path, "common", "reset_sync.v")],
        hdl_toplevel="reset_sync",
        always=True,
    )
    runner.test(
        hdl_toplevel="reset_sync",
        test_module="test_reset_sync",
    )
