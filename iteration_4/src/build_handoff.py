import os
import re
import shutil

src_base = "/home/anupam-sarashwat/Project_penguin3"
dst_base = "/home/anupam-sarashwat/rtl_verification_handoff"

os.makedirs(dst_base, exist_ok=True)

# Regex patterns
module_pattern = re.compile(r'module\s+(\w+)\s*(?:#\s*\([\s\S]*?\))?\s*\(([\s\S]*?)\);')
port_pattern = re.compile(r'(input|output|inout)\s+(?:wire|reg)?\s*(?:\[.*?\]\s*)?(\w+)')
instance_pattern = re.compile(r'^\s*([a-zA-Z0-9_]+)\s+(?:#\s*\([\s\S]*?\)\s*)?([a-zA-Z0-9_]+)\s*\(', re.MULTILINE)

directories = ['common', 'frontend', 'backend', 'interconnect', 'memory', 'security', 'peripherals', 'storage', 'video', 'top']

def parse_verilog(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Strip comments to make parsing reliable
    content_no_comments = re.sub(r'//.*', '', content)
    content_no_comments = re.sub(r'/\*[\s\S]*?\*/', '', content_no_comments)
    
    match = module_pattern.search(content_no_comments)
    if not match:
        return None, [], []
        
    module_name = match.group(1)
    ports_str = match.group(2)
    
    ports = port_pattern.findall(ports_str)
    
    # In some Verilog-2001, ports are declared inside the body.
    if not ports:
        ports = port_pattern.findall(content_no_comments)
        
    instances = instance_pattern.findall(content_no_comments)
    # Filter out keywords
    keywords = {'module', 'endmodule', 'always', 'initial', 'if', 'else', 'assign', 'wire', 'reg', 'logic', 'input', 'output', 'inout', 'always_comb', 'always_ff', 'always_latch', 'parameter', 'localparam', 'begin', 'end', 'case', 'endcase', 'generate', 'endgenerate', 'for', 'while', 'import'}
    
    valid_instances = []
    for mod_type, inst_name in instances:
        if mod_type not in keywords and inst_name not in keywords:
            valid_instances.append((mod_type, inst_name))
            
    return module_name, ports, valid_instances

def generate_tb(module_name, ports):
    tb = f"`timescale 1ns / 1ps\n\nmodule tb_{module_name}();\n\n"
    
    # Declarations
    for p_dir, p_name in ports:
        if p_dir == 'input':
            tb += f"    reg  {p_name};\n"
        else:
            tb += f"    wire {p_name};\n"
            
    tb += f"\n    // DUT Instantiation\n"
    tb += f"    {module_name} uut (\n"
    port_maps = [f"        .{p_name}({p_name})" for _, p_name in ports]
    tb += ",\n".join(port_maps) + "\n    );\n\n"
    
    # Clock generation
    has_clk = any(p_name in ['clk', 'core_clk', 'sys_clk', 'sys_clk_100mhz', 'pixel_clk'] for _, p_name in ports)
    clk_name = 'clk'
    for _, p_name in ports:
        if p_name in ['clk', 'core_clk', 'sys_clk', 'sys_clk_100mhz', 'pixel_clk']:
            clk_name = p_name
            break
            
    if has_clk:
        tb += f"    // Clock Generation (138.8 MHz -> ~7.2ns period)\n"
        tb += f"    initial begin\n"
        tb += f"        {clk_name} = 0;\n"
        tb += f"        forever #3.6 {clk_name} = ~{clk_name};\n"
        tb += f"    end\n\n"
        
    tb += f"    // Initial block for stimulus and VCD dumping\n"
    tb += f"    initial begin\n"
    tb += f"        $dumpfile(\"tb_{module_name}.vcd\");\n"
    tb += f"        $dumpvars(0, tb_{module_name});\n\n"
    
    # Initialize inputs
    tb += f"        // Initialize inputs\n"
    for p_dir, p_name in ports:
        if p_dir == 'input' and p_name != clk_name:
            tb += f"        {p_name} = 0;\n"
            
    # Reset sequence
    rst_name = None
    for _, p_name in ports:
        if p_name in ['rst_n', 'reset_n', 'sys_rst_n']:
            rst_name = p_name
            break
            
    if rst_name:
        tb += f"\n        // Reset sequence\n"
        tb += f"        #10;\n"
        tb += f"        {rst_name} = 1;\n"
        tb += f"        #100;\n"
        
    tb += f"\n        // Add manual test stimulus here...\n\n"
    tb += f"        #1000;\n"
    tb += f"        $finish;\n"
    tb += f"    end\n\n"
    tb += f"endmodule\n"
    
    return tb

def generate_readme(module_name, ports, instances):
    readme = f"# {module_name} Verification Handoff\n\n"
    readme += f"## 📝 Overview\n"
    readme += f"This directory contains the Verilog source, testbench, and verification instructions for the `{module_name}` module.\n\n"
    
    readme += f"## 🎯 What to Test\n"
    readme += f"The verification engineer should ensure that:\n"
    readme += f"1. The module resets correctly and all internal states initialize to safe values.\n"
    readme += f"2. All interface protocols (e.g., AXI4, APB, native valid/ready) are strictly adhered to.\n"
    readme += f"3. Edge cases specific to this IP (e.g., full/empty flags for FIFOs, cache misses for memory, etc.) are manually exercised.\n\n"
    
    readme += f"## 🔍 GTKWave Signals to Observe\n"
    readme += f"Add the following key signals to your GTKWave trace for structural inspection:\n"
    readme += f"### Inputs\n"
    for p_dir, p_name in ports:
        if p_dir == 'input':
            readme += f"- `uut.{p_name}`\n"
    readme += f"\n### Outputs\n"
    for p_dir, p_name in ports:
        if p_dir == 'output':
            readme += f"- `uut.{p_name}`\n"
            
    readme += f"\n## 🏗 Structural Block Diagram\n"
    readme += f"The following Mermaid diagram maps the exact sub-module hierarchy instantiated within `{module_name}`. Use this to verify that structural boundaries match the behavioral expectations.\n\n"
    
    readme += f"```mermaid\n"
    readme += f"graph TD\n"
    if not instances:
        readme += f"    {module_name}[{module_name}] --> |No Sub-Modules| LEAF[Pure Logic]\n"
    else:
        for mod_type, inst_name in instances:
            readme += f"    {module_name} --> |{mod_type}| {inst_name}[{inst_name}]\n"
    readme += f"```\n\n"
    
    readme += f"## ▶️ Simulation Instructions\n"
    readme += f"1. **Compile**: `iverilog -o sim.vvp {module_name}.v tb_{module_name}.v` (Include dependencies using ` -I ../../includes -I` if necessary)\n"
    readme += f"2. **Simulate**: `vvp sim.vvp`\n"
    readme += f"3. **View**: `gtkwave tb_{module_name}.vcd`\n"
    
    return readme

total_modules = 0
for d in directories:
    src_dir = os.path.join(src_base, d)
    if not os.path.isdir(src_dir):
        continue
        
    v_files = [f for f in os.listdir(src_dir) if f.endswith('.v')]
    for vf in v_files:
        src_file = os.path.join(src_dir, vf)
        mod_name, ports, instances = parse_verilog(src_file)
        
        if not mod_name:
            mod_name = vf.replace('.v', '')
            ports = []
            instances = []
            
        # Create destination directory
        dst_dir = os.path.join(dst_base, d, mod_name)
        os.makedirs(dst_dir, exist_ok=True)
        
        # 1. Copy Verilog design
        shutil.copy(src_file, os.path.join(dst_dir, vf))
        
        # 2. Write Testbench
        tb_content = generate_tb(mod_name, ports)
        with open(os.path.join(dst_dir, f"tb_{mod_name}.v"), "w") as f:
            f.write(tb_content)
            
        # 3. Write README
        readme_content = generate_readme(mod_name, ports, instances)
        with open(os.path.join(dst_dir, "README.md"), "w") as f:
            f.write(readme_content)
            
        total_modules += 1

print(f"Generated handoff packages for {total_modules} modules.")
