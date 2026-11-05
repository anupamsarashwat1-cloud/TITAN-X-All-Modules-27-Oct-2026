import os
import subprocess
import glob

directories = ['common', 'frontend', 'backend', 'interconnect', 'memory', 'security', 'peripherals', 'storage', 'video', 'top']
base_dir = "/home/anupam-sarashwat/rtl_verification_handoff"

success = 0
failures = 0

# Find all design files (excluding testbenches)
design_files = []
for root, dirs, files in os.walk(base_dir):
    for file in files:
        if file.endswith('.v') and not file.startswith('tb_'):
            design_files.append(os.path.join(root, file))

for d in directories:
    group_dir = os.path.join(base_dir, d)
    if not os.path.isdir(group_dir):
        continue
        
    for mod in os.listdir(group_dir):
        mod_dir = os.path.join(group_dir, mod)
        if not os.path.isdir(mod_dir):
            continue
            
        tb_file = f"tb_{mod}.v"
        mod_file = f"{mod}.v"
        
        if os.path.exists(os.path.join(mod_dir, tb_file)) and os.path.exists(os.path.join(mod_dir, mod_file)):
            print(f"Testing {mod}...", end=" ", flush=True)
            
            # Write a cmds.f file
            cmds_path = os.path.join(mod_dir, "cmds.f")
            with open(cmds_path, "w") as f:
                for df in design_files:
                    f.write(f"{df}\n")
            
            cmd = [
                "iverilog", "-g2012", "-o", "sim.vvp",
                "-I", "../../includes",
                "-c", "cmds.f",
                tb_file
            ]
            
            result = subprocess.run(cmd, cwd=mod_dir, capture_output=True, text=True)
            if result.returncode == 0:
                print("PASS")
                success += 1
            else:
                print("FAIL")
                print(result.stderr)
                failures += 1

print(f"\nVerification Complete: {success} Passed, {failures} Failed.")
