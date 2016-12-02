
include $(TOOLS_DIR)/make/viv_ip_builder.mak

IP_SP_DDS_SRCS = $(IP_BUILD_DIR)/SP_DDS/SP_DDS.xci

IP_SP_DDS_OUTS = $(addprefix $(IP_BUILD_DIR)/SP_DDS/, \
SP_DDS.xci.out \
synth/SP_DDS.vhd \
)

$(IP_SP_DDS_SRCS) $(IP_SP_DDS_OUTS) : $(IP_DIR)/SP_DDS/SP_DDS.xci
	$(call BUILD_VIVADO_IP,SP_DDS,$(ARCH),$(PART_ID),$(IP_DIR),$(IP_BUILD_DIR),0)
