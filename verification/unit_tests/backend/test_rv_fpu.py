import os
import struct
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb_tools.runner import get_runner

def float_to_int(f):
    return struct.unpack('<I', struct.pack('<f', f))[0]

def int_to_float(i):
    return struct.unpack('<f', struct.pack('<I', i))[0]

@cocotb.test()
async def test_rv_fpu_basic(dut):
    """Test FPU basic operations (FADD SP)"""
    clock = Clock(dut.clk, 10, unit="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.fop.value = 0
    dut.fmt.value = 0
    dut.rm.value = 0
    dut.valid_in.value = 0
    dut.fp_src1.value = 0
    dut.fp_src2.value = 0
    dut.fp_src3.value = 0
    dut.int_src.value = 0
    dut.frm_csr.value = 0
    
    await Timer(22, unit="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # 2.0 + 3.0 = 5.0
    f1 = float_to_int(2.0)
    f2 = float_to_int(3.0)
    
    await FallingEdge(dut.clk)
    dut.fop.value = 0x00    # FOP_FADD = 00000
    dut.fmt.value = 0x00    # FMT_S
    dut.fp_src1.value = f1
    dut.fp_src2.value = f2
    dut.valid_in.value = 1
    
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Wait for fpu_done
    while dut.fpu_done.value == 0:
        await RisingEdge(dut.clk)
        
    res_int = int(dut.fp_result.value) & 0xFFFFFFFF
    res_float = int_to_float(res_int)
    
    assert dut.result_valid.value == 1, "Result should be valid"
    assert res_float == 5.0, f"Expected 5.0, got {res_float}"

def test_rv_fpu_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../..'))
    
    runner = get_runner(sim)
    runner.build(
        sources=[os.path.join(proj_path, "backend", "rv_fpu.v")],
        hdl_toplevel="rv_fpu",
        build_args=["-I" + os.path.join(proj_path, "common")],
        always=True,
    )
    runner.test(
        hdl_toplevel="rv_fpu",
        test_module="test_rv_fpu",
    )
