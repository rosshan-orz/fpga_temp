module digital_filter (
    clk,
    reset,
    data_in,
    data_valid,
    filter_out,
    filter_valid
);

parameter M_SAMPLES = 16; // Number of samples to average (e.g., 16)

input wire clk;
input wire reset; // Synchronous reset
input wire [31:0] data_in; // N_O count value from period_measure
input wire data_valid; // Pulse indicating data_in is valid

output reg [31:0] filter_out; // Averaged N_O value
output reg filter_valid; // Pulse indicating filter_out is valid

// Accumulator for summing M_SAMPLES values.
// $clog2(16) = 4. So ACCUM_WIDTH = 32 + 4 = 36.
localparam LOG2_M_SAMPLES = 4;
localparam ACCUM_WIDTH = 32 + LOG2_M_SAMPLES;
reg [ACCUM_WIDTH-1:0] accumulator;

// Counter for samples. Counts from 0 to M_SAMPLES-1.
reg [LOG2_M_SAMPLES-1:0] sample_count;

always @(posedge clk)
begin
    if (reset) begin
        accumulator <= 0;
        sample_count <= 0;
        filter_out <= 0;
        filter_valid <= 0;
    end else begin
        filter_valid <= 0; // Default to low, asserted only when a new average is ready

        if (data_valid) begin // A new valid data_in sample is available
            if (sample_count == M_SAMPLES - 1) begin
                // This is the M_SAMPLES-th sample. Calculate the average.
                filter_out <= (accumulator + data_in) >> LOG2_M_SAMPLES;
                filter_valid <= 1; // Assert valid for one cycle

                // Reset for the next integration period
                accumulator <= 0;
                sample_count <= 0;
            end else begin
                // Not the last sample yet, so accumulate and increment
                accumulator <= accumulator + data_in;
                sample_count <= sample_count + 1;
            end
        end
    end
end

endmodule
