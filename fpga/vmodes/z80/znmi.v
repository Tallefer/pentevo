// Pentevo project (c) NedoPC 2011
//
// NMI generation

`include "../include/tune.v"

module znmi
(
	input  wire        rst_n,
	input  wire        fclk,

	input  wire        zpos,
	input  wire        zneg,

	input  wire        int_start, // when INT starts
	input  wire [ 1:0] set_nmi,   // NMI request from slavespi

	input  wire        clr_nmi, // clear nmi: from zports, pulsed at out to #xxBE


	input  wire        rfsh_n,
	input  wire        m1_n,
	input  wire        mreq_n,

	input  wire        csrom,

	input  wire [15:0] a,


	output reg         in_nmi, // when 1, there must be last (#FF) ram page in 0000-3FFF

	output wire        gen_nmi // NMI generator: when 1, NMI_N=0, otherwise NMI_N=Z
);

	reg  [1:0] set_nmi_r;
	wire       set_nmi_now;

	reg pending_nmi;

	reg in_nmi_2; // active (=1) when NMIed to ROM, after 0066 M1 becomes 0,
	              // but in_nmi becomes 1 -- ROM switches to #FF RAM


	reg [2:0] nmi_count;

	reg [1:0] clr_count;

	reg pending_clr;


	reg last_m1_rom;

	reg last_m1_0066;




	//remember whether last M1 opcode read was from ROM or RAM
	reg m1_n_reg, mreq_n_reg;
	reg [1:0] rfsh_n_reg;

	always @(posedge fclk) if( zpos )
		rfsh_n_reg[0] <= rfsh_n;
	always @(posedge fclk)
		rfsh_n_reg[1] <= rfsh_n_reg[0];


	always @(posedge fclk) if( zpos )
		m1_n_reg <= m1_n;

	always @(posedge fclk) if( zneg )
		mreq_n_reg <= mreq_n;

	wire was_m1 = ~(m1_n_reg | mreq_n_reg);

	reg was_m1_reg;

	always @(posedge fclk)
		was_m1_reg <= was_m1;


	always @(posedge fclk)
	if( was_m1 && (!was_m1_reg) )
		last_m1_rom <= csrom && (a[15:14]==2'b00);

	always @(posedge fclk)
	if( was_m1 && (!was_m1_reg) )
		last_m1_0066 <= ( a[15:0]==16'h0066 );





	always @(posedge fclk)
		set_nmi_r <= set_nmi;
	//
	assign set_nmi_now = (set_nmi_r[0] && (!set_nmi[0])) ||
	                     (set_nmi_r[1] && (!set_nmi[1])) ;


	always @(posedge fclk, negedge rst_n)
	if( !rst_n )
		pending_nmi <= 1'b0;
	else // posedge clk
	begin
		if( int_start )
			pending_nmi <= 1'b0;
		else if( set_nmi_now )
			pending_nmi <= 1'b1;
	end




	always @(posedge fclk)
	if( clr_nmi )
		clr_count <= 2'd3;
	else if( rfsh_n_reg[1] && (!rfsh_n_reg[0]) && clr_count[1] )
		clr_count <= clr_count - 2'd1;

	always @(posedge fclk)
	if( clr_nmi )
		pending_clr <= 1'b1;
	else if( !clr_count[1] )
		pending_clr <= 1'b0;


	always @(posedge fclk, negedge rst_n)
	if( !rst_n )
		in_nmi_2 <= 1'b0;
	else // posedge fclk
	begin
		if( pending_nmi && int_start && (!in_nmi) && last_m1_rom )
			in_nmi_2 <= 1'b1;
		else if( rfsh_n_reg[1] && (!rfsh_n_reg[0]) && last_m1_0066 )
			in_nmi_2 <= 1'b0;
	end


	always @(posedge fclk, negedge rst_n)
	if( !rst_n )
		in_nmi <= 1'b0;
	else // posedge clk
	begin
		if( pending_clr && (!clr_count[1]) )
			in_nmi <= 1'b0;
		else if( (pending_nmi && int_start && (!in_nmi) && (!last_m1_rom))       ||
		         (rfsh_n_reg[1] && (!rfsh_n_reg[0]) && last_m1_0066 && in_nmi_2) )
			in_nmi <= 1'b1;
	end


	always @(posedge fclk, negedge rst_n)
	if( !rst_n )
		nmi_count <= 3'b000;
	else if( pending_nmi && int_start && (!in_nmi) )
		nmi_count <= 3'b111;
	else if( nmi_count[2] && zpos )
		nmi_count <= nmi_count - 3'd1;


	assign gen_nmi = nmi_count[2];


endmodule

