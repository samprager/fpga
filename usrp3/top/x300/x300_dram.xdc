#
# Copyright 2015-2017 Ettus Research LLC
#

create_generated_clock -name ddr3_axi_clk [get_pins -hierarchical -filter {NAME =~ "*u_ddr3_infrastructure/gen_ui_extra_clocks.mmcm_i/CLKFBOUT"}]
create_generated_clock -name ddr3_axi_clk_x2 [get_pins -hierarchical -filter {NAME =~ "*u_ddr3_infrastructure/gen_ui_extra_clocks.mmcm_i/CLKOUT0"}]

set_clock_groups -asynchronous -group [get_clocks bus_clk] -group [get_clocks mmcm_ps_clk_bufg_in]
set_clock_groups -asynchronous -group [get_clocks bus_clk] -group [get_clocks ddr3_axi_clk]
set_clock_groups -asynchronous -group [get_clocks bus_clk] -group [get_clocks ddr3_axi_clk_x2]

# Floorplan the MIG and the primary AXI4 interconnect
# create_pblock pblock_dram_iface
# resize_pblock pblock_dram_iface -add {SLICE_X104Y0:SLICE_X153Y149 DSP48_X3Y0:DSP48_X5Y59 RAMB18_X3Y0:RAMB18_X6Y59 RAMB36_X3Y0:RAMB36_X6Y29}
# add_cells_to_pblock pblock_dram_iface [get_cells [list u_ddr3_32bit]] -clear_locs
# add_cells_to_pblock pblock_dram_iface [get_cells [list x300_core/axi_intercon_2x64_128_bd_i]] -clear_locs

set_property BITSTREAM.STARTUP.MATCH_CYCLE NoWait [current_design]
set_property BITSTREAM.GENERAL.COMPRESS False [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 6 [current_design]

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 2048 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list radio_clk_gen/inst/CLK_OUT1]]
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe0]
set_property port_width 32 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {x300_core/probe3_r0_0[0]} {x300_core/probe3_r0_0[1]} {x300_core/probe3_r0_0[2]} {x300_core/probe3_r0_0[3]} {x300_core/probe3_r0_0[4]} {x300_core/probe3_r0_0[5]} {x300_core/probe3_r0_0[6]} {x300_core/probe3_r0_0[7]} {x300_core/probe3_r0_0[8]} {x300_core/probe3_r0_0[9]} {x300_core/probe3_r0_0[10]} {x300_core/probe3_r0_0[11]} {x300_core/probe3_r0_0[12]} {x300_core/probe3_r0_0[13]} {x300_core/probe3_r0_0[14]} {x300_core/probe3_r0_0[15]} {x300_core/probe3_r0_0[16]} {x300_core/probe3_r0_0[17]} {x300_core/probe3_r0_0[18]} {x300_core/probe3_r0_0[19]} {x300_core/probe3_r0_0[20]} {x300_core/probe3_r0_0[21]} {x300_core/probe3_r0_0[22]} {x300_core/probe3_r0_0[23]} {x300_core/probe3_r0_0[24]} {x300_core/probe3_r0_0[25]} {x300_core/probe3_r0_0[26]} {x300_core/probe3_r0_0[27]} {x300_core/probe3_r0_0[28]} {x300_core/probe3_r0_0[29]} {x300_core/probe3_r0_0[30]} {x300_core/probe3_r0_0[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe1]
set_property port_width 8 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {x300_core/probe4_r0_0[0]} {x300_core/probe4_r0_0[1]} {x300_core/probe4_r0_0[2]} {x300_core/probe4_r0_0[3]} {x300_core/probe4_r0_0[4]} {x300_core/probe4_r0_0[5]} {x300_core/probe4_r0_0[6]} {x300_core/probe4_r0_0[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe2]
set_property port_width 64 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {x300_core/probe0_r0_0[0]} {x300_core/probe0_r0_0[1]} {x300_core/probe0_r0_0[2]} {x300_core/probe0_r0_0[3]} {x300_core/probe0_r0_0[4]} {x300_core/probe0_r0_0[5]} {x300_core/probe0_r0_0[6]} {x300_core/probe0_r0_0[7]} {x300_core/probe0_r0_0[8]} {x300_core/probe0_r0_0[9]} {x300_core/probe0_r0_0[10]} {x300_core/probe0_r0_0[11]} {x300_core/probe0_r0_0[12]} {x300_core/probe0_r0_0[13]} {x300_core/probe0_r0_0[14]} {x300_core/probe0_r0_0[15]} {x300_core/probe0_r0_0[16]} {x300_core/probe0_r0_0[17]} {x300_core/probe0_r0_0[18]} {x300_core/probe0_r0_0[19]} {x300_core/probe0_r0_0[20]} {x300_core/probe0_r0_0[21]} {x300_core/probe0_r0_0[22]} {x300_core/probe0_r0_0[23]} {x300_core/probe0_r0_0[24]} {x300_core/probe0_r0_0[25]} {x300_core/probe0_r0_0[26]} {x300_core/probe0_r0_0[27]} {x300_core/probe0_r0_0[28]} {x300_core/probe0_r0_0[29]} {x300_core/probe0_r0_0[30]} {x300_core/probe0_r0_0[31]} {x300_core/probe0_r0_0[32]} {x300_core/probe0_r0_0[33]} {x300_core/probe0_r0_0[34]} {x300_core/probe0_r0_0[35]} {x300_core/probe0_r0_0[36]} {x300_core/probe0_r0_0[37]} {x300_core/probe0_r0_0[38]} {x300_core/probe0_r0_0[39]} {x300_core/probe0_r0_0[40]} {x300_core/probe0_r0_0[41]} {x300_core/probe0_r0_0[42]} {x300_core/probe0_r0_0[43]} {x300_core/probe0_r0_0[44]} {x300_core/probe0_r0_0[45]} {x300_core/probe0_r0_0[46]} {x300_core/probe0_r0_0[47]} {x300_core/probe0_r0_0[48]} {x300_core/probe0_r0_0[49]} {x300_core/probe0_r0_0[50]} {x300_core/probe0_r0_0[51]} {x300_core/probe0_r0_0[52]} {x300_core/probe0_r0_0[53]} {x300_core/probe0_r0_0[54]} {x300_core/probe0_r0_0[55]} {x300_core/probe0_r0_0[56]} {x300_core/probe0_r0_0[57]} {x300_core/probe0_r0_0[58]} {x300_core/probe0_r0_0[59]} {x300_core/probe0_r0_0[60]} {x300_core/probe0_r0_0[61]} {x300_core/probe0_r0_0[62]} {x300_core/probe0_r0_0[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe3]
set_property port_width 64 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {x300_core/probe0_awg[0]} {x300_core/probe0_awg[1]} {x300_core/probe0_awg[2]} {x300_core/probe0_awg[3]} {x300_core/probe0_awg[4]} {x300_core/probe0_awg[5]} {x300_core/probe0_awg[6]} {x300_core/probe0_awg[7]} {x300_core/probe0_awg[8]} {x300_core/probe0_awg[9]} {x300_core/probe0_awg[10]} {x300_core/probe0_awg[11]} {x300_core/probe0_awg[12]} {x300_core/probe0_awg[13]} {x300_core/probe0_awg[14]} {x300_core/probe0_awg[15]} {x300_core/probe0_awg[16]} {x300_core/probe0_awg[17]} {x300_core/probe0_awg[18]} {x300_core/probe0_awg[19]} {x300_core/probe0_awg[20]} {x300_core/probe0_awg[21]} {x300_core/probe0_awg[22]} {x300_core/probe0_awg[23]} {x300_core/probe0_awg[24]} {x300_core/probe0_awg[25]} {x300_core/probe0_awg[26]} {x300_core/probe0_awg[27]} {x300_core/probe0_awg[28]} {x300_core/probe0_awg[29]} {x300_core/probe0_awg[30]} {x300_core/probe0_awg[31]} {x300_core/probe0_awg[32]} {x300_core/probe0_awg[33]} {x300_core/probe0_awg[34]} {x300_core/probe0_awg[35]} {x300_core/probe0_awg[36]} {x300_core/probe0_awg[37]} {x300_core/probe0_awg[38]} {x300_core/probe0_awg[39]} {x300_core/probe0_awg[40]} {x300_core/probe0_awg[41]} {x300_core/probe0_awg[42]} {x300_core/probe0_awg[43]} {x300_core/probe0_awg[44]} {x300_core/probe0_awg[45]} {x300_core/probe0_awg[46]} {x300_core/probe0_awg[47]} {x300_core/probe0_awg[48]} {x300_core/probe0_awg[49]} {x300_core/probe0_awg[50]} {x300_core/probe0_awg[51]} {x300_core/probe0_awg[52]} {x300_core/probe0_awg[53]} {x300_core/probe0_awg[54]} {x300_core/probe0_awg[55]} {x300_core/probe0_awg[56]} {x300_core/probe0_awg[57]} {x300_core/probe0_awg[58]} {x300_core/probe0_awg[59]} {x300_core/probe0_awg[60]} {x300_core/probe0_awg[61]} {x300_core/probe0_awg[62]} {x300_core/probe0_awg[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA [get_debug_ports u_ila_0/probe4]
set_property port_width 64 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {x300_core/probe0_r0[0]} {x300_core/probe0_r0[1]} {x300_core/probe0_r0[2]} {x300_core/probe0_r0[3]} {x300_core/probe0_r0[4]} {x300_core/probe0_r0[5]} {x300_core/probe0_r0[6]} {x300_core/probe0_r0[7]} {x300_core/probe0_r0[8]} {x300_core/probe0_r0[9]} {x300_core/probe0_r0[10]} {x300_core/probe0_r0[11]} {x300_core/probe0_r0[12]} {x300_core/probe0_r0[13]} {x300_core/probe0_r0[14]} {x300_core/probe0_r0[15]} {x300_core/probe0_r0[16]} {x300_core/probe0_r0[17]} {x300_core/probe0_r0[18]} {x300_core/probe0_r0[19]} {x300_core/probe0_r0[20]} {x300_core/probe0_r0[21]} {x300_core/probe0_r0[22]} {x300_core/probe0_r0[23]} {x300_core/probe0_r0[24]} {x300_core/probe0_r0[25]} {x300_core/probe0_r0[26]} {x300_core/probe0_r0[27]} {x300_core/probe0_r0[28]} {x300_core/probe0_r0[29]} {x300_core/probe0_r0[30]} {x300_core/probe0_r0[31]} {x300_core/probe0_r0[32]} {x300_core/probe0_r0[33]} {x300_core/probe0_r0[34]} {x300_core/probe0_r0[35]} {x300_core/probe0_r0[36]} {x300_core/probe0_r0[37]} {x300_core/probe0_r0[38]} {x300_core/probe0_r0[39]} {x300_core/probe0_r0[40]} {x300_core/probe0_r0[41]} {x300_core/probe0_r0[42]} {x300_core/probe0_r0[43]} {x300_core/probe0_r0[44]} {x300_core/probe0_r0[45]} {x300_core/probe0_r0[46]} {x300_core/probe0_r0[47]} {x300_core/probe0_r0[48]} {x300_core/probe0_r0[49]} {x300_core/probe0_r0[50]} {x300_core/probe0_r0[51]} {x300_core/probe0_r0[52]} {x300_core/probe0_r0[53]} {x300_core/probe0_r0[54]} {x300_core/probe0_r0[55]} {x300_core/probe0_r0[56]} {x300_core/probe0_r0[57]} {x300_core/probe0_r0[58]} {x300_core/probe0_r0[59]} {x300_core/probe0_r0[60]} {x300_core/probe0_r0[61]} {x300_core/probe0_r0[62]} {x300_core/probe0_r0[63]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list x300_core/probe1_awg]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list x300_core/probe1_r0]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list x300_core/probe1_r0_0]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list x300_core/probe2_awg]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list x300_core/probe2_r0]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list x300_core/probe2_r0_0]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list x300_core/probe5_r0_0]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list x300_core/probe6_r0_0]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets radio_clk]
