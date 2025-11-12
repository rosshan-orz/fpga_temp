module period_measure (
    clk,
    reset,
    sig_fx,
    data_out,
    data_valid
);

parameter N_FX_CYCLES = 10; // Number of sig_fx periods to measure

input wire clk;
input wire reset; // Synchronous reset
input wire sig_fx; // Asynchronous input from NE555
output reg [31:0] data_out;
output reg data_valid;

// --- Asynchronous Input Synchronization ---
reg [1:0] fx_sync_ff;
always @(posedge clk) begin
    if (reset) fx_sync_ff <= 2'b00;
    else fx_sync_ff <= {fx_sync_ff[0], sig_fx};
end
wire sig_fx_synced = fx_sync_ff[1];

// --- Edge Detection for sig_fx_synced ---
reg sig_fx_prev;
wire sig_fx_rise_edge;
always @(posedge clk) begin
    if (reset) sig_fx_prev <= 1'b0;
    else sig_fx_prev <= sig_fx_synced;
end
assign sig_fx_rise_edge = sig_fx_synced && !sig_fx_prev;

// --- State Machine ---
localparam S_IDLE = 2'b00;
localparam S_COUNTING = 2'b01;
localparam S_DONE = 2'b10;

reg [1:0] current_state, next_state;

// Counters
reg [31:0] cnt_N_O; // Counts clk cycles (f_o)
// $clog2(1000+2) = 10
localparam FX_COUNTER_WIDTH = 10;
reg [FX_COUNTER_WIDTH-1:0] cnt_FX_edges;

// Register to hold the final measured count (N_O)
reg [31:0] measured_N_O;

// FSM State Register
always @(posedge clk) begin
    if (reset) current_state <= S_IDLE;
    else current_state <= next_state;
end

// FSM Next State Logic (Combinational)
always @(*) begin
    next_state = current_state; // Default: stay in current state
    case (current_state)
        S_IDLE: begin
            if (sig_fx_rise_edge) begin
                next_state = S_COUNTING; // First edge detected, start counting
            end
        end
        S_COUNTING: begin
            if (sig_fx_rise_edge && cnt_FX_edges == N_FX_CYCLES) begin
                next_state = S_DONE; // All periods measured, transition to DONE
            end
        end
        S_DONE: begin
            next_state = S_IDLE; // Go back to IDLE to await next measurement
        end
        default: next_state = S_IDLE;
    endcase
end

// Counter and Output Logic (Sequential)
always @(posedge clk) begin
    if (reset) begin
        cnt_N_O <= 0;
        cnt_FX_edges <= 0;
        data_out <= 0;
        data_valid <= 0;
        measured_N_O <= 0;
    end else begin
        data_valid <= 0; // Default to low
        case (current_state)
            S_IDLE: begin
                if (next_state == S_COUNTING) begin // Start of measurement
                    cnt_N_O <= 1; // Start counting from 1
                    cnt_FX_edges <= 1; // This is the first edge
                end else begin
                    cnt_N_O <= 0;
                    cnt_FX_edges <= 0;
                end
            end
            S_COUNTING: begin
                cnt_N_O <= cnt_N_O + 1; // Always count system clock cycles
                if (sig_fx_rise_edge) begin
                    cnt_FX_edges <= cnt_FX_edges + 1; // Count sig_fx rising edges
                end
                if (next_state == S_DONE) begin // About to finish
                    measured_N_O <= cnt_N_O + 1; // Capture final count
                end
            end
            S_DONE: begin
                data_valid <= 1; // Assert valid signal
                data_out <= measured_N_O; // Output the captured data
            end
        endcase
    end
end

endmodule
