import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_rv_mem_read(dut):
    """Test memory read operation (LW)"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.flush.value = 0
    dut.alu_result.value = 0
    dut.rs2_data.value = 0
    dut.rd_in.value = 0
    dut.funct3.value = 0
    dut.opcode.value = 0
    dut.mem_read.value = 0
    dut.mem_write.value = 0
    dut.reg_write.value = 0
    dut.valid_in.value = 0
    
    dut.dmem_awready.value = 0
    dut.dmem_wready.value = 0
    dut.dmem_bvalid.value = 0
    dut.dmem_arready.value = 0
    dut.dmem_rvalid.value = 0
    dut.dmem_rdata.value = 0
    dut.dmem_rresp.value = 0
    
    await Timer(22, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Send a read request (LW from 0x1000, write to x5)
    await FallingEdge(dut.clk)
    dut.alu_result.value = 0x1000
    dut.rd_in.value = 5
    dut.funct3.value = 2 # LW (sign-extended 32-bit)
    dut.mem_read.value = 1
    dut.reg_write.value = 1
    dut.valid_in.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert dut.mem_stall.value == 1, "Should stall while memory active"
    assert dut.dmem_arvalid.value == 1, "Should assert ARVALID"
    assert dut.dmem_araddr.value == 0x1000, "ARADDR mismatch"
    
    # Acknowledge address
    await FallingEdge(dut.clk)
    dut.valid_in.value = 0 # Instruction moved from execute
    dut.dmem_arready.value = 1
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.dmem_arready.value = 0
    
    # Wait some cycles
    for _ in range(2):
        await RisingEdge(dut.clk)
        
    # Return data (e.g. 0x80000000, should sign extend to 0xFFFFFFFF80000000)
    await FallingEdge(dut.clk)
    dut.dmem_rvalid.value = 1
    dut.dmem_rdata.value = 0x80000000
    dut.dmem_rresp.value = 0
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.valid_out.value == 1, "Should be valid output"
    assert dut.rd_out.value == 5
    assert dut.reg_write_out.value == 1
    assert dut.result.value == 0xFFFFFFFF80000000, f"Expected sign extension, got {hex(dut.result.value)}"
    assert dut.mem_stall.value == 0, "Stall should clear"

@cocotb.test()
async def test_rv_mem_write(dut):
    """Test memory write operation (SB)"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.flush.value = 0
    dut.alu_result.value = 0
    dut.rs2_data.value = 0
    dut.rd_in.value = 0
    dut.funct3.value = 0
    dut.opcode.value = 0
    dut.mem_read.value = 0
    dut.mem_write.value = 0
    dut.reg_write.value = 0
    dut.valid_in.value = 0
    
    dut.dmem_awready.value = 0
    dut.dmem_wready.value = 0
    dut.dmem_bvalid.value = 0
    dut.dmem_arready.value = 0
    dut.dmem_rvalid.value = 0
    dut.dmem_rdata.value = 0
    dut.dmem_rresp.value = 0
    
    await Timer(22, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Send a write request (SB value 0xAB to 0x2000)
    await FallingEdge(dut.clk)
    dut.alu_result.value = 0x2000
    dut.rs2_data.value = 0xAB
    dut.funct3.value = 0 # SB
    dut.mem_write.value = 1
    dut.reg_write.value = 0
    dut.valid_in.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    assert dut.mem_stall.value == 1
    assert dut.dmem_awvalid.value == 1
    assert dut.dmem_wvalid.value == 1
    assert dut.dmem_wstrb.value == 0x01 # SB mask
    
    # Acknowledge address and data
    await FallingEdge(dut.clk)
    dut.valid_in.value = 0
    dut.dmem_awready.value = 1
    dut.dmem_wready.value = 1
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.dmem_awready.value = 0
    dut.dmem_wready.value = 0
    
    # Send BVALID response
    dut.dmem_bvalid.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.valid_out.value == 1
    assert dut.mem_stall.value == 0

def test_rv_mem_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    
    runner = get_runner(sim)
    runner.build(
        sources=[os.path.join(proj_path, "backend", "rv_mem.v")],
        hdl_toplevel="rv_mem",
        always=True,
    )
    runner.test(
        hdl_toplevel="rv_mem",
        test_module="test_rv_mem",
    )
