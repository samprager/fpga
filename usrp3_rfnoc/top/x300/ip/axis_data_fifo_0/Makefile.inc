
include $(TOOLS_DIR)/make/viv_ip_builder.mak

IP_AXIS_DATA_FIFO_SRCS = $(IP_BUILD_DIR)/axis_data_fifo_0/axis_data_fifo_0.xci

IP_AXIS_DATA_FIFO_OUTS = $(addprefix $(IP_BUILD_DIR)/axis_data_fifo_0/, \
axis_data_fifo_0.xci.out \
synth/axis_data_fifo_0.vhd \
)

$(IP_AXIS_DATA_FIFO_SRCS) $(IP_AXIS_DATA_FIFO_OUTS) : $(IP_DIR)/axis_data_fifo_0/axis_data_fifo_0.xci
	$(call BUILD_VIVADO_IP,axis_data_fifo_0,$(ARCH),$(PART_ID),$(IP_DIR),$(IP_BUILD_DIR),0)
