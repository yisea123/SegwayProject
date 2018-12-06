module steer_en_SM(clk,rst_n,tmr_full,sum_gt_min,sum_lt_min,diff_gt_eigth,
                   diff_gt_15_16,clr_tmr,en_steer,rider_off);

  parameter fast_sim = 1'b0;

  input clk;				// 50MHz clock
  input rst_n;				// Active low asynch reset
  input tmr_full;			// asserted when timer reaches 1.3 sec
  input sum_gt_min;			// asserted when left and right load cells together exceed min rider weight
  input sum_lt_min;			// asserted when left_and right load cells are less than min_rider_weight

  /////////////////////////////////////////////////////////////////////////////
  // HEY BUDDY...you are a moron.  sum_gt_min would simply be ~sum_lt_min. Why
  // have both signals coming to this unit??  ANSWER: What if we had a rider
  // (a child) who's weigth was right at the threshold of MIN_RIDER_WEIGHT?
  // We would enable steering and then disable steering then enable it again,
  // ...  We would make that child crash(children are light and flexible and 
  // resilient so we don't care about them, but it might damage our Segway).
  // We can solve this issue by adding hysteresis.  So sum_gt_min is asserted
  // when the sum of the load cells exceeds MIN_RIDER_WEIGHT + HYSTERESIS and
  // sum_lt_min is asserted when the sum of the load cells is less than
  // MIN_RIDER_WEIGHT - HYSTERESIS.  Now we have noise rejection for a rider
  // who's wieght is right at the threshold.  This hysteresis trick is as old
  // as the hills, but very handy...remember it.
  //////////////////////////////////////////////////////////////////////////// 

  input diff_gt_eigth;		// asserted if load cell difference exceeds 1/8 sum (rider not situated)
  input diff_gt_15_16;		// asserted if load cell difference is great (rider stepping off)
  output reg clr_tmr;			// clears the 1.3sec timer
  output logic en_steer;	// enables steering (goes to balance_cntrl)
  output reg rider_off;			// pulses high for one clock on transition back to initial state
  
  // You fill out the rest...use good SM coding practices ///
  enum bit [1:0] {IDLE, WAIT, STEER} state, nxt_state;

  always @(posedge clk, negedge rst_n)
	if(!rst_n)
	  state <= IDLE;
	else
	  state <= nxt_state;

  always @(state, sum_gt_min, diff_gt_eigth, tmr_full, diff_gt_15_16)
  begin
	nxt_state = IDLE;
	clr_tmr = 0;
	en_steer = 0;
	rider_off = 1;

	case(state)
	  IDLE :  if(sum_gt_min)		// rider exceeds weight limit
		  begin
			nxt_state = WAIT;
			clr_tmr = 1;
			rider_off = 0;
		  end
	  WAIT :  if(sum_lt_min)		// weight dropped below limit
		  begin
			nxt_state = IDLE;
			rider_off = 1;
		  end
		  else if(diff_gt_eigth)	// rider not situated
		  begin
			nxt_state = WAIT;
			clr_tmr = 1;
			rider_off = 0;
		  end
		  else if(tmr_full)		// rider situated for adequate amount of time
		  begin
			nxt_state = STEER;
			en_steer = 1;
			rider_off = 0;
		  end
		  else if(~diff_gt_eigth)	// rider not situated for adequate amount of time
		  begin
			nxt_state = WAIT;
			rider_off = 0;
		  end
	  STEER : if(sum_lt_min)		// weight dropped below limit
		  begin
			nxt_state = IDLE;
			rider_off = 1;
		  end
		  else if(diff_gt_15_16)	// rider is stepping off
		  begin
			nxt_state = WAIT;
			clr_tmr = 1;
			rider_off = 0;
		  end
		  else begin			// rider is on
			nxt_state = STEER;
			en_steer = 1;
			rider_off = 0;
		  end
	  default : nxt_state = IDLE;
	endcase
  end
  
endmodule