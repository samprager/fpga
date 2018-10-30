
include $(TOOLS_DIR)/make/viv_ip_builder.mak

IP_ILA0_SRCS = $(IP_BUILD_DIR)/ila_0/ila_0.xci

IP_ILA0_OUTS = $(addprefix $(IP_BUILD_DIR)/ila_0/, \
ila_0.xci.out \
synth/ila_0.vhd \
)

$(IP_ILA0_SRCS) $(IP_ILA0_OUTS) : $(IP_DIR)/ila_0/ila_0.xci
	$(call BUILD_VIVADO_IP,ila_0,$(ARCH),$(PART_ID),$(IP_DIR),$(IP_BUILD_DIR),0)
