module debounce (
    clk,
    noisy_in,
    clean_pulse
);

parameter CLK_FREQ      = 12_000_000; // 12 MHz
parameter DEBOUNCE_MS   = 20;          // 20ms debounce time

input wire clk;
input wire noisy_in;      // active-high noisy input
output wire clean_pulse;   // single-cycle active-high pulse

// Calculate the number of clock cycles for the debounce delay
// $clog2(12_000_000 / 1000 * 20) = $clog2(240_000) = 18
localparam COUNTER_BITS = 18;
localparam MAX_COUNT = (CLK_FREQ / 1000 * DEBOUNCE_MS) - 1;

// Stage 1: Synchronize the asynchronous input to the system clock domain
reg [1:0] sync_ff;
always @(posedge clk) begin
    sync_ff <= {sync_ff[0], noisy_in};
end
wire synced_in = sync_ff[1];

// Stage 2: Debounce logic
// This counter checks if the synchronized input remains stable for the DEBOUNCE_MS duration.
reg [COUNTER_BITS-1:0] counter = 0;
reg debounced_state = 1'b0; // Holds the stable, debounced state of the input

always @(posedge clk) begin
    if (synced_in != debounced_state) begin
        // Input has changed from the stable state. Start counting.
        if (counter == MAX_COUNT) begin
            // Counter has reached its max value, meaning the new state is stable.
            // Update the stable state and reset the counter.
            debounced_state <= synced_in;
            counter <= 0;
        end else begin
            counter <= counter + 1;
        end
    end else begin
        // Input is the same as the stable state, so it's not changing.
        // Keep the counter reset.
        counter <= 0;
    end
end

// Stage 3: Edge detector
// Generates a single-cycle pulse on the rising edge of the debounced state.
reg prev_debounced_state = 1'b0;
always @(posedge clk) begin
    prev_debounced_state <= debounced_state;
end

assign clean_pulse = (debounced_state == 1'b1) && (prev_debounced_state == 1'b0);

endmodule
