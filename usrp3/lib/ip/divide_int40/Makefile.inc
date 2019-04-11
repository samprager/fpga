#
# Copyright 2015 Ettus Research
#

include $(TOOLS_DIR)/make/viv_ip_builder.mak

LIB_IP_DIVIDE_INT40_SRCS = $(IP_BUILD_DIR)/divide_int40/divide_int40.xci

LIB_IP_DIVIDE_INT40_OUTS = $(addprefix $(IP_BUILD_DIR)/divide_int40/, \
divide_int40.xci.out \
synth/divide_int40.vhd \
)

$(LIB_IP_DIVIDE_INT40_SRCS) $(LIB_IP_DIVIDE_INT40_OUTS) : $(LIB_IP_DIR)/divide_int40/divide_int40.xci
	$(call BUILD_VIVADO_IP,divide_int40,$(ARCH),$(PART_ID),$(LIB_IP_DIR),$(IP_BUILD_DIR),0)
