module Counter(
    input clk,
    input rst,
    input [8:0] max,
    output reg [8:0] out
);
    reg [8:0] cnt;

    always @(posedge clk, posedge rst) begin
        if (rst) cnt <= max;
        else if (cnt == 0) cnt <= max;
        else cnt <= cnt - 1;
    end

    always @(*) out = cnt;

endmodule
