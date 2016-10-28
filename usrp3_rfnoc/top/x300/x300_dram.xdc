#
# Copyright 2015 Ettus Research LLC
#

set_clock_groups -asynchronous -group [get_clocks bus_clk] -group [get_clocks clk_ref_i]
set_clock_groups -asynchronous -group [get_clocks bus_clk] -group [get_clocks clk_pll_i]
set_clock_groups -asynchronous -group [get_clocks bus_clk] -group [get_clocks mmcm_ps_clk_bufg_in]
set_clock_groups -asynchronous -group [get_clocks bus_clk] -group [get_clocks mmcm_clkout0]

set_property BITSTREAM.STARTUP.MATCH_CYCLE NOWAIT [current_design]
set_property BITSTREAM.GENERAL.COMPRESS FALSE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 6 [current_design]
