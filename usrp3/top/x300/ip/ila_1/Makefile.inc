
include $(TOOLS_DIR)/make/viv_ip_builder.mak

IP_ILA1_SRCS = $(IP_BUILD_DIR)/ila_1/ila_1.xci

IP_ILA1_OUTS = $(addprefix $(IP_BUILD_DIR)/ila_1/, \
ila_1.xci.out \
synth/ila_1.vhd \
)

$(IP_ILA1_SRCS) $(IP_ILA1_OUTS) : $(IP_DIR)/ila_1/ila_1.xci
	$(call BUILD_VIVADO_IP,ila_1,$(ARCH),$(PART_ID),$(IP_DIR),$(IP_BUILD_DIR),0)
