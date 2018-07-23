vlib work
vlib msim

vlib msim/blk_mem_gen_v8_3_1
vlib msim/axi_bram_ctrl_v4_0_6
vlib msim/xil_defaultlib

vmap blk_mem_gen_v8_3_1 msim/blk_mem_gen_v8_3_1
vmap axi_bram_ctrl_v4_0_6 msim/axi_bram_ctrl_v4_0_6
vmap xil_defaultlib msim/xil_defaultlib

vcom -work blk_mem_gen_v8_3_1 -64 \
"../../../ipstatic/blk_mem_gen_v8_3_1/simulation/blk_mem_gen_v8_3.vhd" \

vcom -work axi_bram_ctrl_v4_0_6 -64 \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/srl_fifo.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/axi_bram_ctrl_funcs.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/coregen_comp_defs.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/axi_lite_if.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/checkbit_handler_64.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/checkbit_handler.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/correct_one_bit_64.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/correct_one_bit.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/xor18.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/parity.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/ecc_gen.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/lite_ecc_reg.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/axi_lite.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/sng_port_arb.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/ua_narrow.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/wrap_brst.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/rd_chnl.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/wr_chnl.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/full_axi.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/axi_bram_ctrl_top.vhd" \
"../../../ipstatic/axi_bram_ctrl_v4_0_6/hdl/vhdl/axi_bram_ctrl.vhd" \

vcom -work xil_defaultlib -64 \
"../../../../../ip/axi_waveform_bram_ctrl/sim/axi_waveform_bram_ctrl.vhd" \

