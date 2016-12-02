

include $(TOOLS_DIR)/make/viv_ip_builder.mak

IP_AXI_WAVEFORM_DATAMOVER_SRCS = $(IP_BUILD_DIR)/axi_waveform_datamover/axi_waveform_datamover.xci

IP_AXI_WAVEFORM_DATAMOVER_OUTS = $(addprefix $(IP_BUILD_DIR)/axi_waveform_datamover/, \
axi_waveform_datamover.xci.out \
synth/axi_waveform_datamover.vhd \
)

$(IP_AXI_WAVEFORM_DATAMOVER_SRCS) $(IP_AXI_WAVEFORM_DATAMOVER_OUTS) : $(IP_DIR)/axi_waveform_datamover/axi_waveform_datamover.xci
	$(call BUILD_VIVADO_IP,axi_waveform_datamover,$(ARCH),$(PART_ID),$(IP_DIR),$(IP_BUILD_DIR),0)
