read_verilog -Iincludes -D FORMAL -sv \
    security/secure_boot/secure_boot.v \
    formal/sva/secure_boot_formal.sv

prep -top secure_boot_formal -nordff
async2sync
dffunmap
write_smt2 -wires formal/proofs/secure_boot.smt2
