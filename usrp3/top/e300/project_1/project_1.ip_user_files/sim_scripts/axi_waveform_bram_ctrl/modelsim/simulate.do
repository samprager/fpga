onbreak {quit -f}
onerror {quit -f}

vsim -voptargs="+acc" -t 1ps -L secureip -L blk_mem_gen_v8_3_1 -L axi_bram_ctrl_v4_0_6 -L xil_defaultlib -lib xil_defaultlib xil_defaultlib.axi_waveform_bram_ctrl

do {wave.do}

view wave
view structure
view signals

do {axi_waveform_bram_ctrl.udo}

run -all

quit -force
