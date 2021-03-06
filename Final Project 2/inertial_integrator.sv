//Lucas Wysiatko and Donald Gu
module inertial_integrator(clk, rst_n, vld, ptch_rt, AZ, ptch);

  input clk, rst_n;
  input vld;
  input [15:0] ptch_rt, AZ;
  output signed [15:0] ptch;
  reg signed [26:0] ptch_int;  //pitch integrating accumulator

  localparam AZ_OFFSET = 16'hFE80;
  localparam PTCH_RT_OFFSET = 16'h03C2;
  wire signed [26:0] fusion_ptch_offset;
  wire [15:0] ptch_rt_comp;
  wire [15:0] AZ_comp;  //input signals adjusted for respective offsets
  wire signed [25:0] ptch_acc_product;
  wire signed [15:0] ptch_acc;

  //calculate adjusted inputs
  assign ptch_rt_comp = ptch_rt - PTCH_RT_OFFSET;
  assign AZ_comp = AZ - AZ_OFFSET;

  assign ptch_acc_product = $signed(AZ_comp) * $signed(327);  // 327 is fudge factor

  assign ptch = $signed(ptch_int[26:11]);  //assign ptch a scaled version of ptch_int 

  //integrate ptch_rt_comp on every valid pulse
  always@(posedge clk, negedge rst_n)
    if(!rst_n)
      ptch_int <= 28'h0000000;
    else if(vld)
       ptch_int <= ptch_int - $signed({{11{ptch_rt_comp[15]}},ptch_rt_comp}) + fusion_ptch_offset;

  //pitch angle calculated from accel only
  assign ptch_acc = $signed({{3{ptch_acc_product[25]}},ptch_acc_product[25:13]}); 

  //the offset is 512 if accel pitch > gyro pitch and -512 if it is less than gyro pitch
  assign fusion_ptch_offset = (ptch_acc > ptch) ? 27'sd1024 : -27'sd1024; 
 

endmodule
