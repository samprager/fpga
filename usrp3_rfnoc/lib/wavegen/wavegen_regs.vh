
/********************************************************
** Waveform Generator and Radar Control Blocks: 200-223
********************************************************/
localparam [7:0] SR_CH_COUNTER_ADDR = 200;
localparam [7:0] SR_CH_TUNING_COEF_ADDR = 201;
localparam [7:0] SR_CH_FREQ_OFFSET_ADDR = 202;
localparam [7:0] SR_AWG_CTRL_WORD_ADDR = 203;

localparam [7:0] SR_PRF_INT_ADDR = 204;
localparam [7:0] SR_PRF_FRAC_ADDR = 205;
localparam [7:0] SR_ADC_SAMPLE_ADDR = 206;

localparam [7:0] SR_RADAR_CTRL_POLICY = 207;
localparam [7:0] SR_RADAR_CTRL_COMMAND = 208;
localparam [7:0] SR_RADAR_CTRL_TIME_HI = 209;
localparam [7:0] SR_RADAR_CTRL_TIME_LO = 210;
localparam [7:0] SR_RADAR_CTRL_CLEAR_CMDS = 211;
localparam [7:0] SR_AWG_RELOAD = 212;
localparam [7:0] SR_AWG_RELOAD_LAST = 213;

/* Control readback registers */

localparam [7:0] RB_AWG_LEN              = 5;
localparam [7:0] RB_ADC_LEN              = 6;
localparam [7:0] RB_AWG_CTRL             = 7;
localparam [7:0] RB_AWG_PRF              = 8;
localparam [7:0] RB_AWG_POLICY           = 9;
localparam [7:0] RB_AWG_STATE            = 10;
