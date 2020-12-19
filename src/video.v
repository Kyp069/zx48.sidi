//-------------------------------------------------------------------------------------------------
module vdu
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       ce,
	input  wire[ 2:0] border,
	output wire       bi,
	output wire       cn,
	output wire       rd,
	input  wire[ 7:0] d,
	output wire[12:0] a,
	output wire       hs,
	output wire       vs,
	output wire[17:0] rgb
);
//-------------------------------------------------------------------------------------------------

reg[8:0] hCount;
wire hCountReset = hCount >= 447;
always @(posedge clock) if(ce) if(hCountReset) hCount <= 1'd0; else hCount <= hCount+1'd1;

reg[8:0] vCount;
wire vCountReset = vCount >= 311;
always @(posedge clock) if(ce) if(hCountReset) if(vCountReset) vCount <= 1'd0; else vCount <= vCount+1'd1;

reg[4:0] fCount;
always @(posedge clock) if(ce) if(hCountReset) if(vCountReset) fCount <= fCount+1'd1;

//-------------------------------------------------------------------------------------------------

wire dataEnable = hCount <= 255 && vCount <= 191;

reg videoEnable;
wire videoEnableLoad = hCount[3];
always @(posedge clock) if(ce) if(videoEnableLoad) videoEnable <= dataEnable;

//-------------------------------------------------------------------------------------------------

reg[7:0] dataInput;
wire dataInputLoad = (hCount[3:0] ==  9 || hCount[3:0] == 13) && dataEnable;
always @(posedge clock) if(ce) if(dataInputLoad) dataInput <= d;

reg[7:0] attrInput;
wire attrInputLoad = (hCount[3:0] == 11 || hCount[3:0] == 15) && dataEnable;
always @(posedge clock) if(ce) if(attrInputLoad) attrInput <= d;

reg[7:0] dataOutput;
wire dataOutputLoad = hCount[2:0] == 4 && videoEnable;
always @(posedge clock) if(ce) if(dataOutputLoad) dataOutput <= dataInput; else dataOutput <= { dataOutput[6:0], 1'b0 };

reg[7:0] attrOutput;
wire attrOutputLoad = hCount[2:0] == 4;
always @(posedge clock) if(ce) if(attrOutputLoad) attrOutput <= { videoEnable ? attrInput[7:3] : { 2'b00, border }, attrInput[2:0] };


//-------------------------------------------------------------------------------------------------

wire hSync = hCount >= 344 && hCount <= 375;
wire vSync = vCount >= 248 && vCount <= 251;

wire hBlank = hCount >= 320 && hCount <= 415;
wire vBlank = vCount >= 248 && vCount <= 255;

//-------------------------------------------------------------------------------------------------

wire dataSelect = dataOutput[7] ^ (fCount[4] & attrOutput[7]);
wire videoBlank = hBlank | vBlank;

wire r = !videoBlank && (dataSelect ? attrOutput[1] : attrOutput[4]);
wire g = !videoBlank && (dataSelect ? attrOutput[2] : attrOutput[5]);
wire b = !videoBlank && (dataSelect ? attrOutput[0] : attrOutput[3]);
wire i = attrOutput[6];

//-------------------------------------------------------------------------------------------------

assign bi = !(vCount == 248 && hCount >= 0 && hCount <= 63);
assign cn = (hCount[3] || hCount[2]) && dataEnable;
assign rd = hCount[3] && dataEnable;

assign a = { !hCount[1] ? { vCount[7:6], vCount[2:0] } : { 3'b110, vCount[7:6] }, vCount[5:3], hCount[7:4], hCount[2] };

assign hs = hSync;
assign vs = vSync;
assign rgb = { r,{4{r&i}},r, g,{4{g&i}},g, b,{4{b&i}},b };

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
