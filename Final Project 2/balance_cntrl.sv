//Lucas Wysiatko
//Donald Gu
module balance_cntrl(clk,rst_n,pwr_up,vld,ptch,ld_cell_diff,lft_spd,lft_rev,
                     rght_spd,rght_rev,rider_off, en_steer,too_fast);
		
  parameter fast_sim = 1'b0;
						
  input clk,rst_n;
  input pwr_up;
  input vld;						// tells when a new valid inertial reading ready
  input signed [15:0] ptch;			// actual pitch measured
  input signed [11:0] ld_cell_diff;	// lft_ld - rght_ld from steer_en block
  input rider_off;					// High when weight on load cells indicates no rider
  input en_steer;
  output [10:0] lft_spd;			// 11-bit unsigned speed at which to run left motor
  output lft_rev;					// direction to run left motor (1==>reverse)
  output [10:0] rght_spd;			// 11-bit unsigned speed at which to run right motor
  output rght_rev;					// direction to run right motor (1==>reverse)
  output too_fast;
  
  ////////////////////////////////////
  // Define needed registers below //
  //////////////////////////////////
  reg signed [17:0] integrator;
  reg signed [9:0] delay1, prev_ptch_err;
  
  ///////////////////////////////////////////
  // Define needed internal signals below //
  /////////////////////////////////////////
  wire signed [9:0] ptch_err_sat;
  wire signed [14:0] ptch_P_term;
  wire signed [17:0] ptch_err_sat_ext;
  wire signed [11:0] ptch_I_term;
  wire signed [17:0] integral_sum;
  wire signed [17:0] integral_checked;
  wire ov, vld_no_ov;
  wire signed [9:0] ptch_D_diff;
  wire signed [6:0] ptch_D_diff_sat;
  wire signed [12:0] ptch_D_term;
  wire signed [15:0] PID_cntrl;
  wire signed [15:0] lft_torque, rght_torque;
  wire [15:0] lft_torque_abs, rght_torque_abs;
  wire signed [15:0] lft_torque_gain, rght_torque_gain;  //for small values torque needs to be multiplied by a gain
  wire signed [15:0] lft_torque_cyc, rght_torque_cyc;  //torques with min duty cycle added (or subtracted) 
  wire signed [15:0] lft_shaped, rght_shaped;  //chooses between x_torque_ gain and x_torque_cyc depending on 
                                               //whether x_torque >= LOW_TORQUE_BAND
  wire lft_mag_comp, rght_mag_comp;  //1 if >= LOW_TORQUE_BAND
  wire [15:0] lft_shaped_abs, rght_shaped_abs;
  wire signed [15:0] load_cell_diff_adj;


  /////////////////////////////////////////////
  // local params for increased flexibility //
  ///////////////////////////////////////////
  localparam P_COEFF = 5'h0E;
  localparam D_COEFF = 6'h14;				// D coefficient in PID control = +20 
    
  localparam LOW_TORQUE_BAND = 8'h46;	// LOW_TORQUE_BAND = 5*P_COEFF
  localparam GAIN_MULTIPLIER = 6'h0F;	// GAIN_MULTIPLIER = 1 + (MIN_DUTY/LOW_TORQUE_BAND)
  localparam MIN_DUTY = 15'h03D4;		// minimum duty cycle (stiffen motor and get it ready)
  
  //// You fill in the rest ////

  //P(Proportional) component of PID
  assign ptch_err_sat = ptch[15] ? $signed(&ptch[14:9] ? {1'b1, ptch[8:0]} : 10'h200) : 
                        $signed(|ptch[14:9] ? 10'h1FF : {1'b0, ptch[8:0]});  //saturates ptch
  assign ptch_P_term = ptch_err_sat * $signed(P_COEFF);


  //I(Integral) component of PID
  assign ptch_err_sat_ext = $signed({{8{ptch_err_sat[9]}}, ptch_err_sat[9:0]}); //sign extend
  assign integral_sum = ptch_err_sat_ext + integrator; //adder
  assign ov = (integrator[17] == ptch_err_sat_ext[17]) ? (integrator[17] == integral_sum[17]) ? $unsigned(0) : $unsigned(1) : $unsigned(0); // check for overflow 
  assign vld_no_ov = vld & (~ov);
  assign integral_checked = vld_no_ov ? integral_sum : integrator; 
  assign ptch_I_term = $signed(integrator[17:6]);
  always_ff@(posedge clk, negedge rst_n)
    if (!rst_n)
      integrator <= 18'h00000;
    else if (rider_off | !pwr_up)
      integrator <= 18'h00000;
    else 
      integrator <= integral_checked;


  //D(Derivative) component of PID
  always_ff@(posedge clk, negedge rst_n)
    if(!rst_n)
      delay1 <= 10'h000;
    else if(vld)
      delay1 <= ptch_err_sat;

  always_ff@(posedge clk, negedge rst_n)
    if(!rst_n)
      prev_ptch_err <= 10'h000;
    else if(vld)
      prev_ptch_err <= delay1;

  assign ptch_D_diff = ptch_err_sat - prev_ptch_err;
  assign ptch_D_diff_sat = ptch_D_diff[9] ? $signed({1'b1, ptch_D_diff[5:0]}) : $signed({1'b0, ptch_D_diff[5:0]});
  assign ptch_D_term = ptch_D_diff_sat * $signed(D_COEFF);
  

  //PID Math combining
  assign load_cell_diff_adj = ld_cell_diff[11] ? $signed({{7{1'b1}}, ld_cell_diff[11:3]}) :
                              $signed({{7{1'b0}}, ld_cell_diff[11:3]});  //take 1/8 of difference and sign extend
  assign lft_torque = en_steer ? (PID_cntrl - load_cell_diff_adj) : PID_cntrl;
  assign rght_torque = en_steer ? (PID_cntrl + load_cell_diff_adj) : PID_cntrl;
  assign PID_cntrl = $signed({ptch_P_term[14], ptch_P_term}) + $signed({{4{ptch_I_term[11]}}, ptch_I_term}) + 
                     $signed({{3{ptch_D_term[12]}}, ptch_D_term});  //sum P, I, D terms sign extended to 16 bits


  //Shaping torque to form Duty
  assign lft_torque_abs = lft_torque[15] ? $unsigned((~lft_torque + 1)) : $unsigned(lft_torque);
  assign rght_torque_abs = rght_torque[15] ? $unsigned((~rght_torque + 1)) : $unsigned(rght_torque);
  assign lft_mag_comp = lft_torque_abs >= LOW_TORQUE_BAND;
  assign rght_mag_comp = rght_torque_abs >= LOW_TORQUE_BAND;
  assign lft_torque_gain = lft_torque * $signed(GAIN_MULTIPLIER);
  assign rght_torque_gain = rght_torque * $signed(GAIN_MULTIPLIER);

  //if negative subtract min duty, if positive add it
  assign lft_torque_cyc = lft_torque[15] ? $signed((lft_torque - MIN_DUTY)) : $signed((lft_torque + MIN_DUTY));
  assign rght_torque_cyc = rght_torque[15] ? $signed((rght_torque - MIN_DUTY)) : $signed((rght_torque + MIN_DUTY));

  assign lft_shaped = lft_mag_comp ? lft_torque_cyc : lft_torque_gain;
  assign rght_shaped = rght_mag_comp ? rght_torque_cyc : rght_torque_gain;
  assign lft_shaped_abs = lft_shaped[15] ? $unsigned((~lft_shaped + 1)) : $unsigned(lft_shaped);
  assign rght_shaped_abs = rght_shaped[15] ? $unsigned((~rght_shaped + 1)) : $unsigned(rght_shaped);
  assign lft_spd = |lft_shaped_abs[15:11] ? 11'h7FF : lft_shaped_abs;
  assign rght_spd = |rght_shaped_abs[15:11] ? 11'h7FF : rght_shaped_abs;
  assign lft_rev = lft_shaped[15];
  assign rght_rev = rght_shaped[15];
  
  assign too_fast = (lft_spd > 11'h600) || (rght_spd > 11'h600);

endmodule 
