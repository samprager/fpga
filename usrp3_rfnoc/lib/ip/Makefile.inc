#
# Copyright 2016 Ettus Research
#

include $(LIB_IP_DIR)/axi_fir/Makefile.inc
include $(LIB_IP_DIR)/axi_fft/Makefile.inc
include $(LIB_IP_DIR)/axi_hb31/Makefile.inc
include $(LIB_IP_DIR)/axi_hb47/Makefile.inc
include $(LIB_IP_DIR)/complex_to_magphase/Makefile.inc
include $(LIB_IP_DIR)/complex_multiplier/Makefile.inc
include $(LIB_IP_DIR)/cordic_rotator/Makefile.inc
include $(LIB_IP_DIR)/cordic_rotator24/Makefile.inc
include $(LIB_IP_DIR)/divide_int16/Makefile.inc
include $(LIB_IP_DIR)/divide_int24/Makefile.inc
include $(LIB_IP_DIR)/divide_int32/Makefile.inc
include $(LIB_IP_DIR)/divide_uint32/Makefile.inc
include $(LIB_IP_DIR)/divide_int16_int32/Makefile.inc

# include $(GPR_IP_DIR)/axi_waveform_bram_ctrl/Makefile.inc
# include $(GPR_IP_DIR)/axi_waveform_datamover/Makefile.inc
# include $(GPR_IP_DIR)/axis_data_fifo_0/Makefile.inc
# include $(GPR_IP_DIR)/fifo_generator_adc/Makefile.inc
# include $(GPR_IP_DIR)/SP_DDS/Makefile.inc

LIB_IP_XCI_SRCS = \
$(LIB_IP_AXI_FIR_SRCS) \
$(LIB_IP_AXI_FFT_SRCS) \
$(LIB_IP_AXI_HB31_SRCS) \
$(LIB_IP_AXI_HB47_SRCS) \
$(LIB_IP_COMPLEX_TO_MAGPHASE_SRCS) \
$(LIB_IP_COMPLEX_MULTIPLIER_SRCS) \
$(LIB_IP_CORDIC_ROTATOR_SRCS) \
$(LIB_IP_CORDIC_ROTATOR24_SRCS) \
$(LIB_IP_DIVIDE_INT16_SRCS) \
$(LIB_IP_DIVIDE_INT24_SRCS) \
$(LIB_IP_DIVIDE_INT32_SRCS) \
$(LIB_IP_DIVIDE_UINT32_SRCS) \
$(LIB_IP_DIVIDE_INT16_INT32_SRCS) \
# $(LIB_IP_AXI_WAVEFORM_BRAM_SRCS) \
# $(LIB_IP_AXI_WAVEFORM_DATAMOVER_SRCS) \
# $(LIB_IP_AXIS_DATA_FIFO_SRCS) \
# $(LIB_IP_FIFO_GENERATOR_ADC_SRCS) \
# $(LIB_IP_SP_DDS_SRCS)

LIB_IP_SYNTH_OUTPUTS = \
$(LIB_IP_AXI_FIR_OUTS) \
$(LIB_IP_AXI_FFT_OUTS) \
$(LIB_IP_AXI_HB31_OUTS) \
$(LIB_IP_AXI_HB47_OUTS) \
$(LIB_IP_COMPLEX_TO_MAGPHASE_OUTS) \
$(LIB_IP_COMPLEX_MULTIPLIER_OUTS) \
$(LIB_IP_CORDIC_ROTATOR_OUTS) \
$(LIB_IP_CORDIC_ROTATOR24_OUTS) \
$(LIB_IP_DIVIDE_INT16_OUTS) \
$(LIB_IP_DIVIDE_INT24_OUTS) \
$(LIB_IP_DIVIDE_INT32_OUTS) \
$(LIB_IP_DIVIDE_UINT32_OUTS) \
$(LIB_IP_DIVIDE_INT16_INT32_OUTS) \
# $(LIB_IP_AXI_WAVEFORM_BRAM_OUTS) \
# $(LIB_IP_AXI_WAVEFORM_DATAMOVER_OUTS) \
# $(LIB_IP_AXIS_DATA_FIFO_OUTS) \
# $(LIB_IP_FIFO_GENERATOR_ADC_OUTS) \
# $(LIB_IP_SP_DDS_OUTS)

lib_ip: $(LIB_IP_SYNTH_OUTPUTS)

.PHONY: lib_ip
