#
# Copyright 2012-2016 Ettus Research LLC
#

# NOTE: All comments prefixed with a "##" will be displayed as a part of the "make help" target
##-------------------
##USRP X3X0 FPGA Help
##-------------------
##Usage:
## make <Targets> <Options>
##
##Output:
## build/usrp_<product>_fpga_<image_type>.bit:    Configuration bitstream with header
## build/usrp_<product>_fpga_<image_type>.bin:    Configuration bitstream without header
## build/usrp_<product>_fpga_<image_type>.lvbitx: Configuration bitstream for PCIe (NI-RIO)
## build/usrp_<product>_fpga_<image_type>.rpt:    Build report (includes utilization and timing summary)

# Debug Options
# Uncomment the following line to add a debug UART on GPIO 10 & 11
#OPTIONS += DEBUG_UART=1

CREATE_LVBITX=python ../../lib/io_port2/create-lvbitx.py

GIGE_DEFS=BUILD_1G=1 SFP0_1GBE=1 SFP1_1GBE=1 $(OPTIONS)
HG_DEFS=BUILD_1G=1 BUILD_10G=1 SFP0_1GBE=1 SFP1_10GBE=1 $(OPTIONS)
XG_DEFS=BUILD_10G=1 SFP0_10GBE=1 SFP1_10GBE=1 $(OPTIONS)
HA_DEFS=BUILD_1G=1 BUILD_AURORA=1 SFP0_1GBE=1 SFP1_AURORA=1 $(OPTIONS)
XA_DEFS=BUILD_10G=1 BUILD_AURORA=1 SFP0_10GBE=1 SFP1_AURORA=1 $(OPTIONS)
AWG_DEFS=BUILD_1G=1 BUILD_10G=1 SFP0_1GBE=1 SFP1_10GBE=1 BUILD_AWG=1 $(OPTIONS)
CIRAVG_DEFS=BUILD_1G=1 BUILD_10G=1 SFP0_1GBE=1 SFP1_10GBE=1 BUILD_AWG=1 BUILD_CIRAVG=1 $(OPTIONS)
PULSECIRAVG_DEFS=BUILD_1G=1 BUILD_10G=1 SFP0_1GBE=1 SFP1_10GBE=1 BUILD_AWG=1 BUILD_PULSECIRAVG=1 $(OPTIONS)

# Option to stop after RTL elaboration. Use this flag as a synthesis check.
ifdef CHECK
TARGET = rtl
else
TARGET = bin
endif
TOP ?= x300

# vivado_build($1=Device, $2=Definitions)
vivado_build = make -f Makefile.x300.inc $(TARGET) NAME=$@ ARCH=$(XIL_ARCH_$1) PART_ID=$(XIL_PART_ID_$1) $2 TOP_MODULE=$(TOP) EXTRA_DEFS="$2"

# vivado_build($1=Device, $2=Option)
post_build = @\
	mkdir -p build; \
	echo "Exporting bitstream files..."; \
	cp build-$(1)_$(2)/x300.bin build/usrp_`echo $(1) | tr A-Z a-z`_fpga_$(2).bin; \
	cp build-$(1)_$(2)/x300.bit build/usrp_`echo $(1) | tr A-Z a-z`_fpga_$(2).bit; \
	echo "Generating LVBITX..."; \
	$(CREATE_LVBITX) --input-bin=build-$(1)_$(2)/x300.bin --output-lvbitx=build/usrp_`echo $(1) | tr A-Z a-z`_fpga_$(2).lvbitx --device="USRP $(1)" x3x0_base.lvbitx; \
	cp -f x3x0_base.lvbitx build/`echo $(1) | tr A-Z a-z`.lvbitx_base; \
	echo "Exporting build report..."; \
	cp build-$(1)_$(2)/build.rpt build/usrp_`echo $(1) | tr A-Z a-z`_fpga_$(2).rpt; \
	echo "Build DONE ... $(1)_$(2)";

##
##Supported Targets
##-----------------
##(Default target)
all:      X300_HG X310_HG X300_XG X310_XG

##USRP X310. 1GigE on both SFP+ ports. DRAM TX FIFO (Experimental!).
X310_1G:
	$(call vivado_build,X310,$(GIGE_DEFS) X310=1)
	$(call post_build,X310,1G)

##USRP X300. 1GigE on both SFP+ ports. DRAM TX FIFO (Experimental!).
X300_1G:
	$(call vivado_build,X300,$(GIGE_DEFS) X300=1)
	$(call post_build,X300,1G)

##USRP X310. 1GigE on SFP+ Port0, 10Gig on SFP+ Port1. DRAM TX FIFO.
X310_HG:
	$(call vivado_build,X310,$(HG_DEFS) X310=1)
	$(call post_build,X310,HG)

##USRP X300. 1GigE on SFP+ Port0, 10Gig on SFP+ Port1. DRAM TX FIFO.
X300_HG:
	$(call vivado_build,X300,$(HG_DEFS) X300=1)
	$(call post_build,X300,HG)

##USRP X310. 10GigE on both SFP+ ports. DRAM TX FIFO.
X310_XG:
	$(call vivado_build,X310,$(XG_DEFS) X310=1)
	$(call post_build,X310,XG)

##USRP X300. 10GigE on both SFP+ ports. DRAM TX FIFO.
X300_XG:
	$(call vivado_build,X300,$(XG_DEFS) X300=1)
	$(call post_build,X300,XG)

##USRP X310. 1Gig on SFP+ Port0, Aurora on SFP+ Port1. DRAM TX FIFO (Experimental!).
X310_HA:
	$(call vivado_build,X310,$(HA_DEFS) X310=1)
	$(call post_build,X310,HA)

##USRP X300. 1Gig on SFP+ Port0, Aurora on SFP+ Port1. DRAM TX FIFO (Experimental!).
X300_HA:
	$(call vivado_build,X300,$(HA_DEFS) X300=1)
	$(call post_build,X300,HA)

##USRP X310. 10Gig on SFP+ Port0, Aurora on SFP+ Port1. DRAM TX FIFO (Experimental!).
X310_XA:
	$(call vivado_build,X310,$(XA_DEFS) X310=1)
	$(call post_build,X310,XA)

##USRP X300. 10Gig on SFP+ Port0, Aurora on SFP+ Port1. DRAM TX FIFO (Experimental!).
X300_XA:
	$(call vivado_build,X300,$(XA_DEFS) X300=1)
	$(call post_build,X300,XA)

##X310_RFNOC_HG: 1GigE on SFP+ Port0, 10Gig on SFP+ Port1. RFNoC CEs enabled.
X310_RFNOC_HG:
	$(call vivado_build,X310,$(HG_DEFS) RFNOC=1 X310=1)
	$(call post_build,X310,RFNOC_HG)

##X300_RFNOC_HG: 1GigE on SFP+ Port0, 10Gig on SFP+ Port1. RFNoC CEs enabled.
X300_RFNOC_HG:
	$(call vivado_build,X300,$(HG_DEFS) RFNOC=1 X300=1)
	$(call post_build,X300,RFNOC_HG)

##X310_RFNOC_XG: 10GigE on both SFP+ ports. RFNoC CEs enabled.
X310_RFNOC_XG:
	$(call vivado_build,X310,$(XG_DEFS) RFNOC=1 X310=1)
	$(call post_build,X310,RFNOC_XG)

##X300_RFNOC_XG: 10GigE on both SFP+ ports. RFNoC CEs enabled.
X300_RFNOC_XG:
	$(call vivado_build,X300,$(XG_DEFS) RFNOC=1 X300=1)
	$(call post_build,X300,RFNOC_XG)

X300_RFNOC_AWG: ##USRP X300 AWG. 1GigE on SFP+ Port0, 10Gig on SFP+ Port1. RFNoC CEs enabled. (Use HLS=1 to build HLS IP)
	$(call vivado_build,X300,$(AWG_DEFS) RFNOC=1 X300=1 AWG=1)
	$(call post_build,X300,RFNOC_AWG)

X300_RFNOC_CIRAVG: ##USRP X300 AWG. 1GigE on SFP+ Port0, 10Gig on SFP+ Port1. RFNoC CEs enabled. (Use HLS=1 to build HLS IP)
	$(call vivado_build,X300,$(CIRAVG_DEFS) RFNOC=1 X300=1 AWG=1 CIRAVG=1)
	$(call post_build,X300,RFNOC_CIRAVG)

## SARINA KAPAI EDIT
X300_RFNOC_PULSECIRAVG: ##USRP X300 AWG. 1GigE on SFP+ Port0, 10Gig on SFP+ Port1. RFNoC CEs enabled. (Use HLS=1 to build HLS IP)
		$(call vivado_build,X300,$(PULSECIRAVG_DEFS) RFNOC=1 X300=1 AWG=1 PULSECIRAVG=1)
		$(call post_build,X300,RFNOC_PULSECIRAVG)

clean:    ##Clean up all target build outputs.
	@echo "Cleaning targets..."
	@rm -rf build-X3*_*
	@rm -rf build

cleanall: ##Clean up all target and ip build outputs.
	@echo "Cleaning targets and IP..."
	@rm -rf build-ip
	@rm -rf build-X3*_*
	@rm -rf build

help:     ##Show this help message.
	@grep -h "##" Makefile | grep -v "\"##\"" | sed -e 's/\\$$//' | sed -e 's/##//'

##
##Supported Options
##-----------------
##GUI=1        Launch the build in the Vivado GUI.
##CHECK=1      Launch the syntax checker instead of building a bitfile.
##TOP=<module> Specify a top module for syntax checking. (Optional. Default is the bitfile top)

.PHONY: all clean cleanall help
