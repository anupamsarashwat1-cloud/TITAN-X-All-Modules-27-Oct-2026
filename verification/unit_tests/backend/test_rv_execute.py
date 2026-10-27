import os
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb_tools.runner import get_runner

@cocotb.test()
async def test_rv_execute_alu(dut):
    """Test basic ALU ops (ADD, SUB) and forwarding"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    # Init inputs
    dut.stall.value = 0
    dut.flush.value = 0
    dut.pc_in.value = 0
    dut.rs1_data.value = 0
    dut.rs2_data.value = 0
    dut.imm.value = 0
    dut.rd_in.value = 0
    dut.rs1_addr.value = 0
    dut.rs2_addr.value = 0
    dut.funct3.value = 0
    dut.funct7.value = 0
    dut.opcode.value = 0
    dut.alu_op.value = 0
    dut.mem_read.value = 0
    dut.mem_write.value = 0
    dut.reg_write.value = 0
    dut.branch.value = 0
    dut.jal.value = 0
    dut.jalr.value = 0
    dut.is_amo.value = 0
    dut.amo_funct5.value = 0
    dut.valid_in.value = 0
    
    dut.fwd_mem_data.value = 0
    dut.fwd_mem_valid.value = 0
    dut.fwd_mem_rd.value = 0
    dut.fwd_wb_data.value = 0
    dut.fwd_wb_valid.value = 0
    dut.fwd_wb_rd.value = 0
    
    dut.fpu_result.value = 0
    dut.fpu_valid.value = 0
    dut.fpu_done.value = 0
    
    dut.rst_n.value = 0
    await Timer(22, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Send ADD x3, x1, x2 (rs1=10, rs2=20) -> 30
    await FallingEdge(dut.clk)
    dut.rs1_data.value = 10
    dut.rs2_data.value = 20
    dut.rs1_addr.value = 1
    dut.rs2_addr.value = 2
    dut.rd_in.value = 3
    dut.opcode.value = 0x33 # OP_REG
    dut.alu_op.value = 0    # ALU_ADD
    dut.valid_in.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.valid_out.value == 1, "Output should be valid"
    assert dut.alu_result.value == 30, "ADD should be 30"
    
    # Send SUB x4, x1, x2 but with forwarding for x1 from MEM stage (val=100) -> 100-20 = 80
    await FallingEdge(dut.clk)
    dut.rs1_data.value = 10
    dut.rs2_data.value = 20
    dut.rs1_addr.value = 1
    dut.rs2_addr.value = 2
    dut.rd_in.value = 4
    dut.opcode.value = 0x33
    dut.alu_op.value = 1    # ALU_SUB
    dut.fwd_mem_valid.value = 1
    dut.fwd_mem_rd.value = 1
    dut.fwd_mem_data.value = 100
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.valid_out.value == 1
    assert dut.alu_result.value == 80, "SUB with forwarding should be 80"

@cocotb.test()
async def test_rv_execute_branch(dut):
    """Test branch resolution"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.stall.value = 0
    dut.flush.value = 0
    dut.valid_in.value = 0
    dut.pc_in.value = 0
    dut.rs1_data.value = 0
    dut.rs2_data.value = 0
    dut.imm.value = 0
    dut.rd_in.value = 0
    dut.rs1_addr.value = 0
    dut.rs2_addr.value = 0
    dut.funct3.value = 0
    dut.funct7.value = 0
    dut.opcode.value = 0
    dut.alu_op.value = 0
    dut.mem_read.value = 0
    dut.mem_write.value = 0
    dut.reg_write.value = 0
    dut.branch.value = 0
    dut.jal.value = 0
    dut.jalr.value = 0
    dut.is_amo.value = 0
    dut.amo_funct5.value = 0
    
    dut.fwd_mem_data.value = 0
    dut.fwd_mem_valid.value = 0
    dut.fwd_mem_rd.value = 0
    dut.fwd_wb_data.value = 0
    dut.fwd_wb_valid.value = 0
    dut.fwd_wb_rd.value = 0
    
    dut.fpu_result.value = 0
    dut.fpu_valid.value = 0
    dut.fpu_done.value = 0
    
    await Timer(22, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # BEQ x1, x2, offset where x1 == x2
    await FallingEdge(dut.clk)
    dut.pc_in.value = 0x80000000
    dut.rs1_data.value = 42
    dut.rs2_data.value = 42
    dut.rs1_addr.value = 1
    dut.rs2_addr.value = 2
    dut.imm.value = 16
    dut.opcode.value = 0x63 # OP_BRANCH
    dut.funct3.value = 0    # BEQ
    dut.branch.value = 1
    dut.valid_in.value = 1
    
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    
    assert dut.branch_taken.value == 1, "Branch should be taken"
    assert dut.branch_target.value == 0x80000010, "Target should be PC + offset"
    
def test_rv_execute_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    
    runner = get_runner(sim)
    runner.build(
        sources=[os.path.join(proj_path, "backend", "rv_execute.v")],
        hdl_toplevel="rv_execute",
        build_args=["-I" + os.path.join(proj_path, "common")],
        always=True,
    )
    runner.test(
        hdl_toplevel="rv_execute",
        test_module="test_rv_execute",
    )
