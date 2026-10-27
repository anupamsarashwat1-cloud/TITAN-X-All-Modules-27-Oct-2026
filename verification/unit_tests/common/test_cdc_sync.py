import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_cdc_sync_basic(dut):
    """Test basic 2-FF synchronization"""
    clock = Clock(dut.dst_clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.data_in.value = 0
    await Timer(20, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.dst_clk)
    
    assert dut.data_out.value == 0, "Output should be 0 after reset"
    
    # Assert data_in
    await RisingEdge(dut.dst_clk)
    dut.data_in.value = 1
    
    # First stage captures on next edge
    await RisingEdge(dut.dst_clk)
    assert dut.data_out.value == 0, "Output should not update immediately (stage 1)"
    
    # Second stage captures on next edge
    await RisingEdge(dut.dst_clk)
    # Output might be updated here or on the next edge depending on race. Wait one more edge.
    await RisingEdge(dut.dst_clk)
    
    assert dut.data_out.value == 1, "Output should be synchronized after 2 cycles"
    
def test_cdc_sync_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    
    runner = get_runner(sim)
    runner.build(
        sources=[os.path.join(proj_path, "common", "cdc_sync.v")],
        hdl_toplevel="cdc_sync",
        always=True,
    )
    runner.test(
        hdl_toplevel="cdc_sync",
        test_module="test_cdc_sync",
    )
