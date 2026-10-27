import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_rv_writeback_basic(dut):
    """Test writeback behavior including x0 optimization and forwarding"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.result.value = 0
    dut.rd_in.value = 0
    dut.reg_write.value = 0
    dut.valid_in.value = 0
    
    await Timer(22, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 1. Normal writeback to x1
    await FallingEdge(dut.clk)
    dut.result.value = 0xDEADBEEF
    dut.rd_in.value = 1
    dut.reg_write.value = 1
    dut.valid_in.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.wb_data.value == 0xDEADBEEF
    assert dut.wb_rd.value == 1
    assert dut.wb_we.value == 1
    assert dut.fwd_wb_valid.value == 1
    assert dut.fwd_wb_data.value == 0xDEADBEEF
    
    # 2. Writeback to x0 (should not enable write)
    await FallingEdge(dut.clk)
    dut.result.value = 0xCAFEBABE
    dut.rd_in.value = 0
    dut.reg_write.value = 1
    dut.valid_in.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.wb_we.value == 0
    assert dut.fwd_wb_valid.value == 0
    
    # 3. Invalid instruction
    await FallingEdge(dut.clk)
    dut.result.value = 0x11111111
    dut.rd_in.value = 2
    dut.reg_write.value = 1
    dut.valid_in.value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.wb_we.value == 0
    assert dut.fwd_wb_valid.value == 0

def test_rv_writeback_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    
    runner = get_runner(sim)
    runner.build(
        sources=[os.path.join(proj_path, "backend", "rv_writeback.v")],
        hdl_toplevel="rv_writeback",
        always=True,
    )
    runner.test(
        hdl_toplevel="rv_writeback",
        test_module="test_rv_writeback",
    )
