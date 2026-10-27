import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_rv_icache_miss_and_hit(dut):
    """Test I-Cache miss, AXI refill, and subsequent hit"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Init inputs
    dut.cpu_addr.value = 0
    dut.cpu_req.value = 0
    dut.invalidate.value = 0
    dut.m_arready.value = 0
    dut.m_rvalid.value = 0
    dut.m_rdata.value = 0
    dut.m_rlast.value = 0
    dut.m_rresp.value = 0
    
    dut.rst_n.value = 0
    await Timer(22, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Request from CPU: addr 0x8000_0008 (Word 2 of cache line)
    await FallingEdge(dut.clk)
    dut.cpu_req.value = 1
    dut.cpu_addr.value = 0x80000008
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.cpu_stall.value == 1, "Cache should stall CPU on miss"
    
    # Wait for ARVALID
    while dut.m_arvalid.value == 0:
        await RisingEdge(dut.clk)
        
    assert dut.m_araddr.value == 0x80000000, "Refill should be aligned to 64 bytes"
    assert dut.m_arlen.value == 7, "Refill should be 8 beats"
    
    # AXI ARREADY
    await FallingEdge(dut.clk)
    dut.m_arready.value = 1
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.m_arready.value = 0
    
    # Provide 8 beats of data
    for i in range(8):
        # We will populate data so we can verify word extraction.
        # Beat i has 8 bytes. For i=1 (bytes 8-15):
        # Let's say beat 1 data is 0xDDDDDDDDCCCCCCCC (C is word 2, D is word 3)
        if i == 1:
            data = 0xDDDDDDDDCCCCCCCC
        else:
            data = i
            
        dut.m_rvalid.value = 1
        dut.m_rdata.value = data
        dut.m_rlast.value = 1 if i == 7 else 0
        
        await RisingEdge(dut.clk)
        while dut.m_rready.value == 0:
            await RisingEdge(dut.clk)
        await FallingEdge(dut.clk)
        
    dut.m_rvalid.value = 0
    dut.m_rlast.value = 0
    
    # Cache should now respond to the CPU
    while dut.cpu_valid.value == 0:
        await RisingEdge(dut.clk)
        
    assert dut.cpu_rdata.value == 0xCCCCCCCC, f"Data mismatch: {hex(dut.cpu_rdata.value)}"
    
    # Deassert request
    await FallingEdge(dut.clk)
    dut.cpu_req.value = 0
    
    # Wait a few cycles
    for _ in range(3):
        await RisingEdge(dut.clk)
        
    # Request same line, different word: 0x8000_000C (Word 3)
    await FallingEdge(dut.clk)
    dut.cpu_req.value = 1
    dut.cpu_addr.value = 0x8000000C
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.cpu_stall.value == 0, "Should not stall on hit"
    assert dut.cpu_valid.value == 1, "Should be valid immediately (0-cycle hit)"
    assert dut.cpu_rdata.value == 0xDDDDDDDD, f"Data mismatch: {hex(dut.cpu_rdata.value)}"

def test_rv_icache_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    
    runner = get_runner(sim)
    runner.build(
        sources=[os.path.join(proj_path, "frontend", "rv_icache.v")],
        hdl_toplevel="rv_icache",
        build_args=["-I" + os.path.join(proj_path, "common")],
        always=True,
    )
    runner.test(
        hdl_toplevel="rv_icache",
        test_module="test_rv_icache",
    )
