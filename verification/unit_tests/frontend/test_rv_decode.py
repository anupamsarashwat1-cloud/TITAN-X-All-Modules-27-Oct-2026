import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_rv_decode_basic(dut):
    """Test instruction decoding for ADDI and ADD"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Init inputs
    dut.stall.value = 0
    dut.flush.value = 0
    dut.pc_in.value = 0
    dut.instr_in.value = 0
    dut.valid_in.value = 0
    dut.wb_rd.value = 0
    dut.wb_data.value = 0
    dut.wb_we.value = 0
    
    dut.rst_n.value = 0
    await Timer(22, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Send ADDI x1, x0, 15 (0x00f00093)
    await FallingEdge(dut.clk)
    dut.pc_in.value = 0x80000000
    dut.instr_in.value = 0x00f00093
    dut.valid_in.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.valid_out.value == 1, "Decode valid out should be high"
    assert dut.opcode.value == 0x13, "Opcode should be OP_IMM (0010011)"
    assert dut.rd.value == 1, "RD should be x1"
    assert dut.rs1_addr.value == 0, "RS1 should be x0"
    assert dut.imm.value == 15, "Immediate should be 15"
    assert dut.alu_op.value == 0, "ALU OP should be ALU_ADD (0)"
    assert dut.reg_write.value == 1, "Should write to register"
    
    # Write back 15 to x1
    await FallingEdge(dut.clk)
    dut.valid_in.value = 0
    dut.wb_we.value = 1
    dut.wb_rd.value = 1
    dut.wb_data.value = 15
    await RisingEdge(dut.clk)
    
    # Send ADD x2, x1, x1 (0x00108133)
    await FallingEdge(dut.clk)
    dut.wb_we.value = 0
    dut.pc_in.value = 0x80000004
    dut.instr_in.value = 0x00108133
    dut.valid_in.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.valid_out.value == 1
    assert dut.opcode.value == 0x33, "Opcode should be OP_REG (0110011)"
    assert dut.rd.value == 2, "RD should be x2"
    assert dut.rs1_addr.value == 1, "RS1 should be x1"
    assert dut.rs2_addr.value == 1, "RS2 should be x1"
    # Should read x1 as 15 from the register file
    assert dut.rs1_data.value == 15, "RS1 data should be 15"
    assert dut.rs2_data.value == 15, "RS2 data should be 15"
    assert dut.alu_op.value == 0, "ALU OP should be ALU_ADD (0)"

def test_rv_decode_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    
    runner = get_runner(sim)
    runner.build(
        sources=[os.path.join(proj_path, "frontend", "rv_decode.v")],
        hdl_toplevel="rv_decode",
        build_args=["-I" + os.path.join(proj_path, "common")],
        always=True,
    )
    runner.test(
        hdl_toplevel="rv_decode",
        test_module="test_rv_decode",
    )
