module A2D_intf_tb();

reg clk, rst_n, nxt;

wire MISO, a2d_SS_n, SCLK, MOSI;
wire [11:0] lft_ld, rght_ld, batt;

A2D_intf iDUT(.clk(clk), .rst_n(rst_n), .nxt(nxt), .MISO(MISO), .lft_ld(lft_ld), .rght_ld(rght_ld), .batt(batt), .a2d_SS_n(a2d_SS_n), .SCLK(SCLK), .MOSI(MOSI));

ADC128S A2D(.clk(clk), .rst_n(rst_n), .SS_n(a2d_SS_n), .SCLK(SCLK), .MISO(MISO), .MOSI(MOSI));

initial begin
	clk = 0;
	rst_n = 0;
	nxt = 0;

	repeat (2) @(negedge clk);
	rst_n = 1;
repeat (1100) begin
	@(negedge clk) nxt = 1;
	@(negedge clk) nxt = 0;

	@(lft_ld)
	repeat (2) @(negedge clk);

	$display("lft_ld = %h", lft_ld);

	@(negedge clk) nxt = 1;
	@(negedge clk) nxt = 0;

	@(rght_ld)
	repeat (2) @(negedge clk);

	$display("rght_ld = %h", rght_ld);

	@(negedge clk) nxt = 1;
	@(negedge clk) nxt = 0;

	@(batt)
	repeat (2) @(negedge clk);

	$display("batt = %h", batt);
end
	$stop;

end

always
	#5 clk <= ~clk;

endmodule
