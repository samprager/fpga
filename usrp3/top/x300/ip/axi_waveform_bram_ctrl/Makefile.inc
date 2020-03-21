
include $(TOOLS_DIR)/make/viv_ip_builder.mak

IP_AXI_WAVEFORM_BRAM_SRCS = $(IP_BUILD_DIR)/axi_waveform_bram_ctrl/axi_waveform_bram_ctrl.xci

IP_AXI_WAVEFORM_BRAM_OUTS = $(addprefix $(IP_BUILD_DIR)/axi_waveform_bram_ctrl/, \
axi_waveform_bram_ctrl.xci.out \
synth/axi_waveform_bram_ctrl.vhd \
)

$(IP_AXI_WAVEFORM_BRAM_SRCS) $(IP_AXI_WAVEFORM_BRAM_OUTS) : $(IP_DIR)/axi_waveform_bram_ctrl/axi_waveform_bram_ctrl.xci
	$(call BUILD_VIVADO_IP,axi_waveform_bram_ctrl,$(ARCH),$(PART_ID),$(IP_DIR),$(IP_BUILD_DIR),0)
