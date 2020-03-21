##################################################
# Include OOT makefiles
##################################################

include $(LIB_DIR)/wavegen/Makefile.srcs
include $(LIB_DIR)/cir_avg/Makefile.srcs
include $(LIB_DIR)/pulse_cir_avg/Makefile.srcs
include $(LIB_DIR)/doppler_tracker/Makefile.srcs

ifdef BUILD_AWG
	AWG_SRCS = $(WAVEGEN_SRCS)
else
	AWG_SRCS =
endif

ifdef BUILD_DOPPLERTRACK
	DOPPLERTRACK_SRCS = $(DOPPLER_TRACKER_SRCS)
else
	DOPPLERTRACK_SRCS =
endif

ifdef BUILD_CIRAVG
	CIRAVG_SRCS = $(CIR_AVG_SRCS)
else
	CIRAVG_SRCS =
endif

## SARINA KAPAI EDIT
ifdef BUILD_PULSECIRAVG
	PULSECIRAVG_SRCS = $(PULSE_CIR_AVG_SRCS)
else
	PULSECIRAVG_SRCS =
endif
