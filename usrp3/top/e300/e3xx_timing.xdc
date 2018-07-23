###############################################################################
# Timing Constraints for E300 mother board
###############################################################################

# 10MHz / PPS References
create_clock -period 100.000 -name PPS_EXT_IN [get_nets PPS_EXT_IN]
create_clock -period 100.000 -name GPS_PPS [get_nets GPS_PPS]

# Asynchronous clock domains
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks *clk_50MHz_in] -group [get_clocks -include_generated_clocks PPS_EXT_IN] -group [get_clocks -include_generated_clocks GPS_PPS]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks *clk_200M_o] -group [get_clocks -include_generated_clocks PPS_EXT_IN] -group [get_clocks -include_generated_clocks GPS_PPS]

# User GPIO
set_max_delay -datapath_only -from [all_registers -edge_triggered] -to [get_ports PL_GPIO*] 15.000
set_min_delay -from [all_registers -edge_triggered] -to [get_ports PL_GPIO*] 5.000
set_max_delay -datapath_only -from [get_ports PL_GPIO*] -to [all_registers -edge_triggered] 15.000
set_min_delay -from [get_ports PL_GPIO*] -to [all_registers -edge_triggered] 5.000

###############################################################################
## Asynchronous paths
###############################################################################
set_false_path -from [get_ports ONSWITCH_DB]



