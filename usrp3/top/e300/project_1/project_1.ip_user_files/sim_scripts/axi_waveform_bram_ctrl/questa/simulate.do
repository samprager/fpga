onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib axi_waveform_bram_ctrl_opt

do {wave.do}

view wave
view structure
view signals

do {axi_waveform_bram_ctrl.udo}

run -all

quit -force
