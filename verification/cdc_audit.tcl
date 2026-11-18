# CDC Audit Script
analyze -format verilog {top/titan_x_top/titan_x_top.v}
elaborate titan_x_top
check_cdc
report_cdc_violations
