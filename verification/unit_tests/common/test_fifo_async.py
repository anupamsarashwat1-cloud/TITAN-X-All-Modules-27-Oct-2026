import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_fifo_async_basic(dut):
    """Test basic write and read across asynchronous domains"""
    # Create two clocks with different frequencies
    wr_clock = Clock(dut.wr_clk, 10, unit="ns")
    rd_clock = Clock(dut.rd_clk, 15, unit="ns")
    cocotb.start_soon(wr_clock.start())
    cocotb.start_soon(rd_clock.start())
    
    # Initialize
    dut.wr_rst_n.value = 0
    dut.rd_rst_n.value = 0
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    dut.wr_data.value = 0
    await Timer(30, unit="ns")
    
    # Release reset
    dut.wr_rst_n.value = 1
    dut.rd_rst_n.value = 1
    await RisingEdge(dut.wr_clk)
    await RisingEdge(dut.rd_clk)
    
    # Wait for synchronizers to settle
    for _ in range(5):
        await RisingEdge(dut.wr_clk)
        
    assert dut.empty.value == 1, "FIFO should be empty after reset"
    assert dut.full.value == 0, "FIFO should not be full after reset"
    
    # Write a value
    dut.wr_en.value = 1
    dut.wr_data.value = 0x55
    await RisingEdge(dut.wr_clk)
    dut.wr_en.value = 0
    
    # Wait for write pointer to propagate to read domain (takes a few read cycles)
    for _ in range(5):
        await RisingEdge(dut.rd_clk)
        
    assert dut.empty.value == 0, "FIFO should not be empty after write propagates"
    
    # Read the value
    dut.rd_en.value = 1
    await RisingEdge(dut.rd_clk)
    dut.rd_en.value = 0
    
    await RisingEdge(dut.rd_clk)
    assert dut.rd_data.value == 0x55, f"Expected 0x55, got {dut.rd_data.value}"
    
    # Wait for read pointer to propagate back to write domain
    for _ in range(5):
        await RisingEdge(dut.wr_clk)
        
    # Full should remain 0
    assert dut.full.value == 0, "FIFO should not be full"

def test_fifo_async_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    
    runner = get_runner(sim)
    runner.build(
        sources=[os.path.join(proj_path, "common", "fifo_async.v")],
        hdl_toplevel="fifo_async",
        always=True,
    )
    runner.test(
        hdl_toplevel="fifo_async",
        test_module="test_fifo_async",
    )
