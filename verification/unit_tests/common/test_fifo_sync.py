import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_fifo_sync_basic(dut):
    """Test basic write and read operations of fifo_sync"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    dut.wr_data.value = 0
    await Timer(20, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Verify empty
    assert dut.empty.value == 1, "FIFO should be empty after reset"
    assert dut.full.value == 0, "FIFO should not be full after reset"
    assert dut.count.value == 0, "FIFO count should be 0"

    # Write a value
    dut.wr_en.value = 1
    dut.wr_data.value = 0xAA
    await RisingEdge(dut.clk)
    dut.wr_en.value = 0
    
    await RisingEdge(dut.clk)
    assert dut.empty.value == 0, "FIFO should not be empty after write"
    assert dut.count.value == 1, "FIFO count should be 1"
    
    # Read the value
    dut.rd_en.value = 1
    await RisingEdge(dut.clk)
    dut.rd_en.value = 0
    
    # Check data is updated on next cycle (registered read output)
    await RisingEdge(dut.clk)
    assert dut.rd_data.value == 0xAA, f"Read data mismatch: expected 0xAA, got {dut.rd_data.value}"
    assert dut.empty.value == 1, "FIFO should be empty after read"

@cocotb.test()
async def test_fifo_sync_full_empty(dut):
    """Test full and empty flags, and overflow/underflow prevention"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.wr_en.value = 0
    dut.rd_en.value = 0
    dut.wr_data.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Fill the FIFO (Depth is parameterized, default 16 but lets rely on full flag)
    # Actually wait, DEPTH is a generic. In verilog we can read it directly but it's easier to just write until full.
    depth = 16
    for i in range(depth):
        dut.wr_en.value = 1
        dut.wr_data.value = i
        await RisingEdge(dut.clk)
        
    dut.wr_en.value = 0
    await RisingEdge(dut.clk)
    
    assert dut.full.value == 1, "FIFO should be full"
    assert int(dut.count.value) == depth, f"FIFO count should be {depth}"
    
    # Try overflow (write when full)
    dut.wr_en.value = 1
    dut.wr_data.value = 0xFF
    await RisingEdge(dut.clk)
    dut.wr_en.value = 0
    await RisingEdge(dut.clk)
    
    assert dut.full.value == 1, "FIFO should still be full"
    assert int(dut.count.value) == depth, "FIFO count should not exceed depth"
    
    # Read everything out
    for i in range(depth):
        dut.rd_en.value = 1
        await RisingEdge(dut.clk)
        dut.rd_en.value = 0
        await RisingEdge(dut.clk)
        assert dut.rd_data.value == i, f"Read data mismatch at idx {i}: expected {i}, got {dut.rd_data.value}"

    assert dut.empty.value == 1, "FIFO should be empty"
    
    # Try underflow (read when empty)
    dut.rd_en.value = 1
    await RisingEdge(dut.clk)
    dut.rd_en.value = 0
    await RisingEdge(dut.clk)
    
    assert dut.empty.value == 1, "FIFO should remain empty after underflow attempt"

def test_fifo_sync_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    
    runner = get_runner(sim)
    runner.build(
        sources=[os.path.join(proj_path, "common", "fifo_sync.v")],
        hdl_toplevel="fifo_sync",
        always=True,
    )
    runner.test(
        hdl_toplevel="fifo_sync",
        test_module="test_fifo_sync",
    )
