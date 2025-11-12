module display_driver (
    clk,
    reset,
    mode,
    data_in,
    bcd_data,
    cn
);

// --- I/O Ports ---
input wire clk;
input wire reset;
input wire [1:0] mode;
input wire [15:0] data_in;
output reg [3:0] bcd_data;
output reg [3:0] cn;  // 4-digit cathode select, active-low

// --- Clock Dividers ---
localparam SCAN_CLK_DIV = 4000;
reg [11:0] scan_clk_counter;
wire scan_clk_rise;

always @(posedge clk)
begin
    if (reset) scan_clk_counter <= 0;
    else if (scan_clk_counter == SCAN_CLK_DIV - 1) scan_clk_counter <= 0;
    else scan_clk_counter <= scan_clk_counter + 1;
end
assign scan_clk_rise = (scan_clk_counter == SCAN_CLK_DIV - 1);

// --- Data Registers ---
reg [3:0] digits [0:3];
reg [1:0] scan_digit_sel;

// --- Binary to BCD Converter ---
reg [15:0] bcd_out;
reg [15:0] bin_temp; // Moved declaration here
integer i; // Moved declaration here
always @(data_in)
begin
    bin_temp = data_in;
    bcd_out = 0;
    for (i = 0; i < 16; i = i + 1) begin
        if (bcd_out[3:0]   >= 5) bcd_out[3:0]   = bcd_out[3:0] + 3;
        if (bcd_out[7:4]   >= 5) bcd_out[7:4]   = bcd_out[7:4] + 3;
        if (bcd_out[11:8]  >= 5) bcd_out[11:8]  = bcd_out[11:8] + 3;
        if (bcd_out[15:12] >= 5) bcd_out[15:12] = bcd_out[15:12] + 3;
        bcd_out = {bcd_out[14:0], bin_temp[15]};
        bin_temp = bin_temp << 1;
    end
end

// --- Main Display Mux Logic (Sequential) ---
// This single always block drives the 'digits' register to avoid multiple drivers.
always @(posedge clk)
begin
    if (reset) begin
        digits[0] <= 15; digits[1] <= 15; digits[2] <= 15; digits[3] <= 15;
    end else begin
        case (mode)
            2'b00: begin // Mode 0: Show fixed Student ID "0029"
                digits[3] <= 4'd0;
                digits[2] <= 4'd0;
                digits[1] <= 4'd2;
                digits[0] <= 4'd9;
            end
            2'b01: begin // Mode 1: Display numerical data
                digits[3] <= bcd_out[15:12];
                digits[2] <= bcd_out[11:8];
                digits[1] <= bcd_out[7:4];
                digits[0] <= bcd_out[3:0];
            end
            default: begin // Blank display
                digits[3] <= 15; digits[2] <= 15; digits[1] <= 15; digits[0] <= 15;
            end
        endcase
    end
end

// --- Multiplexer and Digit Scanning ---
always @(posedge clk)
begin
    if (reset) scan_digit_sel <= 0;
    else if (scan_clk_rise) scan_digit_sel <= scan_digit_sel + 1;
end

always @(scan_digit_sel or digits[0] or digits[1] or digits[2] or digits[3])
begin
    bcd_data = digits[scan_digit_sel];
    cn = ~(4'b0001 << scan_digit_sel);
end

endmodule