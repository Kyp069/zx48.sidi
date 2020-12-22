//-------------------------------------------------------------------------------------------------
module memory
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock56,
	input  wire       clock28,
	output wire       ready,

	input  wire       reset,
	input  wire       rfsh,
	input  wire       mreq,
	input  wire       iorq,
	input  wire       wr,
	input  wire       rd,
	input  wire       m1,

	input  wire       ce,
	input  wire[ 7:0] d,
	output wire[ 7:0] q,
	input  wire[15:0] a,

	input  wire       vce,
	output wire[ 7:0] vq,
	input  wire[12:0] va,

	output wire       ramCk,
	output wire       ramCe,
	output wire       ramCs,
	output wire       ramWe,
	output wire       ramRas,
	output wire       ramCas,
	output wire[ 1:0] ramDqm,
	inout  wire[15:0] ramDQ,
	output wire[ 1:0] ramBA,
	output wire[12:0] ramA
);
//-------------------------------------------------------------------------------------------------

reg forcemap;
reg automap;
reg mapram;
reg m1on;
reg[3:0] mappage;

always @(posedge clock28) if(ce)
if(!reset)
begin
	forcemap <= 1'b0;
	automap <= 1'b0;
	mappage <= 4'd0;
	mapram <= 1'b0;
	m1on <= 1'b0;
end
else
begin
	if(!iorq && !wr && a[7:0] == 8'hE3)
	begin
		forcemap <= d[7];
		mappage <= d[3:0];
		mapram <= d[6]|mapram;
	end

	if(!mreq && !m1)
	begin
		if(a == 16'h0000 || a == 16'h0008 || a == 16'h0038 || a == 16'h0066 || a == 16'h04C6 || a == 16'h0562)
			m1on <= 1'b1; // activate automapper after this cycle

		else if(a[15:3] == 13'h3FF)
			m1on <= 1'b0; // deactivate automapper after this cycle

		else if(a[15:8] == 8'h3D)
		begin
			m1on <= 1'b1; // activate automapper immediately
			automap <= 1'b1;
		end
	end

	if(m1) automap <= m1on;
end

wire map = forcemap || automap;
wire[3:0] page = !a[13] && mapram ? 4'd3 : mappage;

//-------------------------------------------------------------------------------------------------

wire[ 7:0] romQ;
wire[13:0] romA = a[13:0];

rom #(.AW(14), .FN("48.hex")) Rom
(
	.clock  (clock28),
	.ce     (ce     ),
	.q      (romQ   ),
	.a      (romA   )
);

//-------------------------------------------------------------------------------------------------

wire[ 7:0] esxQ;
wire[12:0] esxA = a[12:0];

rom #(.AW(13), .FN("esxdos.hex")) Esxdos
(
	.clock  (clock28),
	.ce     (ce     ),
	.q      (esxQ   ),
	.a      (esxA   )
);

//-------------------------------------------------------------------------------------------------

wire dprWe2 = (!mreq && !wr && a[15:13] == 3'b010);

wire[12:0] dprA1 = { va[12:7], !rfsh && a[15:14] == 2'b01 ? a[6:0] : va[6:0] };
wire[12:0] dprA2 = a[12:0];

dpr Ram
(
	.rdclock  (clock28),
	.rdclocken(vce    ),
	.q        (vq     ),
	.rdaddress(dprA1  ),
	.wrclock  (clock28),
	.wrclocken(ce     ),
	.wren     (dprWe2 ),
	.data     (d      ),
	.wraddress(dprA2  )
);

//-------------------------------------------------------------------------------------------------

wire sdrWr = !(!mreq && !wr && (a[15] || a[14] || (a[13] && map)));
wire sdrRd = !(!mreq && !rd && (a[15] || a[14] || (a[13] && map) || (!a[13] && map && mapram)));

wire[15:0] sdrD = {2{d}};
wire[15:0] sdrQ;
wire[23:0] sdrA  = { 5'b00000, a[15:14] == 2'b00 && map ? { 2'b01, page, a[12:0] } : { 2'b00, 1'b0, a } };

sdram SDram
(
	.clock  (clock56),
	.reset  (reset  ),
	.ready  (ready  ),
	.refresh(rfsh   ),
	.write  (sdrWr  ),
	.read   (sdrRd  ),
	.portD  (sdrD   ),
	.portQ  (sdrQ   ),
	.portA  (sdrA   ),
	.ramCk  (ramCk  ),
	.ramCe  (ramCe  ),
	.ramCs  (ramCs  ),
	.ramRas (ramRas ),
	.ramCas (ramCas ),
	.ramWe  (ramWe  ),
	.ramDqm (ramDqm ),
	.ramDQ  (ramDQ  ),
	.ramBA  (ramBA  ),
	.ramA   (ramA   )
);

//-------------------------------------------------------------------------------------------------

assign q = a[15:13] == 3'b000 && map && !mapram ? esxQ : a[15:14] == 2'b00 && !map ? romQ : sdrQ[7:0];

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
