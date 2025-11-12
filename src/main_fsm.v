`timescale 1ns / 1ps

module main_fsm (
    input wire clk,
    input wire rst_n,
    input wire single_trig_pulse,
    input wire filter_valid,
    input wire [15:0] filter_data,
    output reg [1:0] display_mode,
    output reg [15:0] display_data,
    output reg buzzer_en
);

    // --- State Definitions (Fixed-Point Implementation) ---
    localparam S_IDLE              = 8'd0;
    localparam S_TEST_WAIT_N       = 8'd21;
    localparam S_TEST_CALC_P1      = 8'd22; // Product 1
    localparam S_TEST_CALC_P2      = 8'd23; // Product 2 (Fixed-Point)
    localparam S_TEST_CALC_ADD     = 8'd25;
    localparam S_TEST_SHOW         = 8'd26;
    localparam S_SHOW_HOLD         = 8'd27;

    reg [7:0] state, next_state;

    // --- Data & Calculation Registers ---
    reg [15:0] reg_cal_N[0:3];
    reg [15:0] reg_cal_L[0:3];
    reg [15:0] N_O_reg;
    reg [15:0] L_O_reg;
    
    // --- Fixed-Point Calculation Registers ---
    reg [32:0] product1;
    reg [48:0] product2;

    // --- Timer for holding result display ---
    localparam SHOW_HOLD_TIME = 26'd60000000; // 5s at 12MHz
    reg [25:0] show_hold_timer;
    wire show_hold_timer_done = (show_hold_timer == SHOW_HOLD_TIME - 1);

    // --- Combinational Logic for Interpolation (SYNTAX FIX) ---
    wire [1:0] i_comb;
    wire [16:0] delta_L_comb;
    wire [15:0] recip_N_comb; // Wire to hold the selected reciprocal

    assign i_comb = (N_O_reg < reg_cal_N[1]) ? 0 : 
                  (N_O_reg < reg_cal_N[2]) ? 1 : 2;

    assign delta_L_comb = reg_cal_L[i_comb+1] - reg_cal_L[i_comb];

    // Combinational selector for the reciprocal value (replaces unsupported array initialization)
    assign recip_N_comb = (i_comb == 2'd0) ? 16'd626 :
                        (i_comb == 2'd1) ? 16'd1339 : 16'd1363;


    // --- Combinational Logic: Next State Calculation ---
    always @(*) begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (single_trig_pulse) begin
                    next_state = S_TEST_WAIT_N;
                end else begin
                    next_state = S_IDLE;
                end
            end
            
            // --- Test Mode Cycle (Fixed-Point) ---
            S_TEST_WAIT_N: if (filter_valid) next_state = S_TEST_CALC_P1;
            S_TEST_CALC_P1: next_state = S_TEST_CALC_P2;
            S_TEST_CALC_P2: next_state = S_TEST_CALC_ADD;
            S_TEST_CALC_ADD: next_state = S_TEST_SHOW;
            S_TEST_SHOW: next_state = S_SHOW_HOLD; // Go to hold state
            S_SHOW_HOLD: begin
                if (show_hold_timer_done) begin
                    next_state = S_IDLE;
                end else begin
                    next_state = S_SHOW_HOLD;
                end
            end
            
            default: next_state = S_IDLE;
        endcase
    end

    // --- Sequential Logic: State, Registers, and Outputs ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            display_mode <= 2'b00; // Start with fixed student ID 0029
            display_data <= 0;
            buzzer_en <= 1'b0;
            L_O_reg <= 0;
            N_O_reg <= 0;
            product1 <= 0;
            product2 <= 0;
            show_hold_timer <= 0;

            // Keep calibration values
            reg_cal_L[0] <= 16'd0;     reg_cal_N[0] <= 16'd918;
            reg_cal_L[1] <= 16'd1000;  reg_cal_N[1] <= 16'd27248;
            reg_cal_L[2] <= 16'd1500;  reg_cal_N[2] <= 16'd40001;
            reg_cal_L[3] <= 16'd2000;  reg_cal_N[3] <= 16'd51792;
        end else begin
            state <= next_state;

            // Timer logic
            if (next_state == S_SHOW_HOLD && state != S_SHOW_HOLD) begin
                show_hold_timer <= 0; // Reset timer when entering hold state
            end else if (state == S_SHOW_HOLD) begin
                if (!show_hold_timer_done) begin
                    show_hold_timer <= show_hold_timer + 1;
                end
            end

            case (state)
                S_IDLE: begin
                    display_mode <= 2'b00; // Fixed student ID 0029
                    display_data <= 0;
                    buzzer_en <= 1'b0; // Buzzer off in IDLE
                end

                // --- Test Mode States (Fixed-Point) ---
                S_TEST_WAIT_N: begin
                    display_mode <= 2'b01; // Switch to data display mode
                    if (filter_valid) N_O_reg <= filter_data;
                    buzzer_en <= 1'b0; // Buzzer off during wait
                end
                S_TEST_CALC_P1: begin
                    product1 <= (N_O_reg - reg_cal_N[i_comb]) * delta_L_comb;
                    buzzer_en <= 1'b0; // Buzzer off during calc
                end
                S_TEST_CALC_P2: begin
                    product2 <= product1 * recip_N_comb;
                    buzzer_en <= 1'b0; // Buzzer off during calc
                end
                S_TEST_CALC_ADD: begin
                    L_O_reg <= reg_cal_L[i_comb] + (product2 >> 24);
                    buzzer_en <= 1'b0; // Buzzer off during calc
                end
                S_TEST_SHOW: begin
                    display_mode <= 2'b01;
                    display_data <= L_O_reg;
                    buzzer_en <= 1'b1; // Buzzer ON here
                end
                S_SHOW_HOLD: begin
                    display_mode <= 2'b01; // Keep showing data
                    display_data <= L_O_reg;
                    buzzer_en <= 1'b1; // Buzzer ON during hold
                end
                
                default: begin
                    display_mode <= 2'b00;
                    buzzer_en <= 1'b0; // Buzzer off by default
                end
            endcase
        end
    end

endmodule
