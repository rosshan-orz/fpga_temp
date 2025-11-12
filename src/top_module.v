module top_module (
    CLK_12M,
    KEY_SINGLE,
    SIG_FX,
    BCD_DATA,
    SEG_CN,
    BUZZER
);

// --- I/O Ports ---
input wire CLK_12M;
input wire KEY_SINGLE;
input wire SIG_FX;
output wire [3:0] BCD_DATA;
output wire [3:0] SEG_CN;
output wire BUZZER;

// --- Reset Logic (Active High) with Power-On Reset ---
reg [15:0] power_on_reset_counter = 0;
wire internal_power_on_reset;

always @(posedge CLK_12M) begin
    if (power_on_reset_counter != 16'hFFFF) begin
        power_on_reset_counter <= power_on_reset_counter + 1;
    end
end

assign internal_power_on_reset = (power_on_reset_counter != 16'hFFFF);
wire reset = internal_power_on_reset;

// --- Internal Wires ---
wire single_trig_pulse;
wire [31:0] period_data;
wire period_valid;
wire [31:0] filter_data;
wire filter_valid;
wire [15:0] display_data_wire;
wire [1:0]  display_mode_wire;
wire        buzzer_en;

// --- Passive Buzzer Square Wave Generator (C4 Note: ~261.6Hz) ---
reg [15:0] buzzer_div_cnt = 0;
reg buzzer_square_wave = 0;
localparam BUZZER_HALF_PERIOD = 22936; // 12MHz / (261.6Hz * 2)

always @(posedge CLK_12M) begin
    if (buzzer_div_cnt >= BUZZER_HALF_PERIOD - 1) begin
        buzzer_div_cnt <= 0;
        buzzer_square_wave <= ~buzzer_square_wave;
    end else begin
        buzzer_div_cnt <= buzzer_div_cnt + 1;
    end
end

assign BUZZER = buzzer_en & buzzer_square_wave;

// --- Module Instantiations ---
debounce debounce_inst (
    .clk(CLK_12M),
    .noisy_in(KEY_SINGLE),
    .clean_pulse(single_trig_pulse)
);

period_measure period_measure_inst (
    .clk(CLK_12M),
    .reset(reset),
    .sig_fx(SIG_FX),
    .data_out(period_data),
    .data_valid(period_valid)
);

digital_filter digital_filter_inst (
    .clk(CLK_12M),
    .reset(reset),
    .data_in(period_data),
    .data_valid(period_valid),
    .filter_out(filter_data),
    .filter_valid(filter_valid)
);

main_fsm main_fsm_inst (
    .clk(CLK_12M),
    .rst_n(~reset), // Inverted reset to match active-low
    .single_trig_pulse(single_trig_pulse),
    .filter_valid(filter_valid),
    .filter_data(filter_data[15:0]), // Connect only lower 16 bits
    .display_mode(display_mode_wire),
    .display_data(display_data_wire),
    .buzzer_en(buzzer_en)
);

display_driver display_driver_inst (
    .clk(CLK_12M),
    .reset(reset),
    .mode(display_mode_wire),
    .data_in(display_data_wire),
    .bcd_data(BCD_DATA),
    .cn(SEG_CN)
);

endmodule
