//-------------------------------------------------------------------------------------------------
module zx48
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock27,

	output wire       led,

	output wire[ 1:0] sync,
	output wire[17:0] rgb,

	input  wire       ear,
	output wire[ 1:0] audio,

	output wire       ramCk,
	output wire       ramCe,
	output wire       ramCs,
	output wire       ramWe,
	output wire       ramRas,
	output wire       ramCas,
	output wire[ 1:0] ramDqm,
	inout  wire[15:0] ramDQ,
	output wire[ 1:0] ramBA,
	output wire[12:0] ramA,

	input  wire       cfgD0,
	input  wire       spiCk,
	input  wire       spiS2,
	input  wire       spiS3,
	input  wire       spiDi,
	output wire       spiDo
);
//-------------------------------------------------------------------------------------------------

clock Clock
(
	.inclk0(clock27),
	.c0    (clock56),
	.locked(clockOn)
);

reg[3:0] ce;
always @(negedge clock56) ce <= ce+1'd1;

wire ce7M0p = ~ce[0] & ~ce[1] &  ce[2];
wire ce7M0n = ~ce[0] & ~ce[1] & ~ce[2];

wire ce3M5p = ~ce[0] & ~ce[1] & ~ce[2] &  ce[3];
wire ce3M5n = ~ce[0] & ~ce[1] & ~ce[2] & ~ce[3];

//-------------------------------------------------------------------------------------------------

reg[5:0] rs;
wire powerOn = rs[5];
always @(posedge clock56) if(cc3M5p) if(!rs[5]) rs <= rs+1'd1;

//-------------------------------------------------------------------------------------------------

reg mreqt23iorqtw3;
always @(posedge clock56) if(cc3M5p) mreqt23iorqtw3 <= mreq & ioFE;

reg cpuck;
always @(posedge clock56) if(ce7M0n) cpuck <= !(cpuck && contend);

wire contend = !(vduCn && cpuck && mreqt23iorqtw3 && ((!a[15] && a[14]) || !ioFE));

wire cc3M5p = ce3M5n & contend;
wire cc3M5n = ce3M5p & contend;

//-------------------------------------------------------------------------------------------------

wire reset = powerOn & clockOn & memOn & keyF11 & osdRs;
wire nmi = keyF5 & osdNmi;

reg mi = 1'b1;
always @(posedge clock56) if(cc3M5p) mi <= vduI;

wire[ 7:0] d;
wire[ 7:0] q;
wire[15:0] a;

cpu Cpu
(
	.clock  (clock56),
	.cep    (cc3M5p ),
	.cen    (cc3M5n ),
	.reset  (reset  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.m1     (m1     ),
	.nmi    (nmi    ),
	.mi     (mi     ),
	.d      (d      ),
	.q      (q      ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

reg mic;
reg speaker;
reg[2:0] border;

wire ioFE = !(!iorq && !a[0]);
always @(posedge clock56) if(ce7M0n) if(!ioFE && !wr) { speaker, mic, border } <= q[4:0];

//-------------------------------------------------------------------------------------------------

wire[ 7:0] memQ;
wire[ 7:0] memVQ;
wire[12:0] memVA = vduA;

memory Mem
(
	.clock  (clock56),
	.reset  (reset  ),
	.ready  (memOn  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.m1     (m1     ),
	.ce     (cc3M5p ),
	.d      (q      ),
	.q      (memQ   ),
	.a      (a      ),
	.vce    (ce7M0p ),
	.vq     (memVQ  ),
	.va     (memVA  ),
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

wire[ 7:0] vduD = memVQ;
wire[12:0] vduA;
wire[17:0] vduRGB;

vdu Vdu
(
	.clock  (clock56),
	.ce     (ce7M0n ),
	.border (border ),
	.bi     (vduI   ),
	.cn     (vduCn  ),
	.rd     (vduRd  ),
	.d      (vduD   ),
	.a      (vduA   ),
	.hs     (vduHs  ),
	.vs     (vduVs  ),
	.rgb    (vduRGB )
);

//-------------------------------------------------------------------------------------------------

wire psgMix = keyF8 & osdMix;

wire[7:0] psgA1;
wire[7:0] psgB1;
wire[7:0] psgC1;

wire[7:0] psgA2;
wire[7:0] psgB2;
wire[7:0] psgC2;

audio Aud
(
	.clock  (clock56),
	.reset  (reset  ),
	.speaker(speaker),
	.mic    (mic    ),
	.ear    (~ear   ),
	.a1     (psgA1  ),
	.b1     (psgB1  ),
	.c1     (psgC1  ),
	.a2     (psgA2  ),
	.b2     (psgB2  ),
	.c2     (psgC2  ),
	.mix    (psgMix ),
	.audio  (audio  )
);

//-------------------------------------------------------------------------------------------------

wire[1:0] keyPs2 = { ps2_kbd_data, ps2_kbd_clk };

wire[4:0] keyQ;
wire[7:0] keyA = a[15:8];

keyboard Key
(
	.clock  (clock56),
	.ce     (ce7M0p ),
	.ps2    (keyPs2 ),
	.f5     (keyF5  ),
	.f8     (keyF8  ),
	.f11    (keyF11 ),
	.q      (keyQ   ),
	.a      (keyA   )
);

//-------------------------------------------------------------------------------------------------

wire bdir = !iorq && a[15] && !a[1] && !wr;
wire bc1  = !iorq && a[15] && !a[1] && a[14] && (!rd || !wr);
wire[7:0] psgQ;

turbosound TS
(
	.clock  (clock56),
	.ce     (ce3M5p ),
	.reset  (reset  ),
	.bdir   (bdir   ),
	.bc1    (bc1    ),
	.d      (q      ),
	.q      (psgQ   ),
	.a1     (psgA1  ),
	.b1     (psgB1  ),
	.c1     (psgC1  ),
	.a2     (psgA2  ),
	.b2     (psgB2  ),
	.c2     (psgC2  )
);

//-------------------------------------------------------------------------------------------------

wire[7:0] usdQ;
wire[7:0] usdA = a[7:0];

usd uSD
(
	.clock  (clock56),
	.cep    (ce7M0p ),
	.cen    (ce7M0n ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.d      (q      ),
	.q      (usdQ   ),
	.a      (usdA   ),
	.cs     (spi_cs ),
	.ck     (spi_ck ),
	.miso   (spi_do ),
	.mosi   (spi_di )
);

//-------------------------------------------------------------------------------------------------

wire ioEB = !(!iorq && a[7:0] == 8'hEB); // uSD
wire ioFFFD = !(!iorq && a[15] && a[14] && !a[1]); // psg

assign d
	= !mreq ? memQ
	: !ioEB ? usdQ
	: !ioFE ? { 1'b1, ~ear|speaker, 1'b1, keyQ }
	: !ioFFFD ? psgQ
	: !iorq & vduRd ? vduD
	: 8'hFF;

//-------------------------------------------------------------------------------------------------

//assign led = 1'b0;//assign led = { usdCs, ~psgMix }; // clockOn & powerOn };

//-------------------------------------------------------------------------------------------------

localparam CONF_STR = {
	"ZX48;;",
	"O2,PSG Mixer,ACB,ABC;",
	"OFG,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
	"T1,NMI;",
	"T0,Reset;",
	"V,v1.0"
};

wire        ps2_kbd_clk;
wire        ps2_kbd_data;

wire  [1:0] buttons;
wire  [1:0] switches;
wire        scandoubler_disable;
wire        ypbpr;
wire [31:0] status;

wire        sd_rd_plus3;
wire        sd_wr_plus3;
wire [31:0] sd_lba_plus3;
wire [7:0]  sd_buff_din_plus3;

wire        sd_rd_wd;
wire        sd_wr_wd;
wire [31:0] sd_lba_wd;
wire [7:0]  sd_buff_din_wd;

wire        sd_busy_mmc;
wire        sd_rd_mmc;
wire        sd_wr_mmc;
wire [31:0] sd_lba_mmc;
wire  [7:0] sd_buff_din_mmc;

wire [31:0] sd_lba = sd_busy_mmc ? sd_lba_mmc : (plus3_fdd_ready ? sd_lba_plus3 : sd_lba_wd);
wire  [1:0] sd_rd = { sd_rd_plus3 | sd_rd_wd, sd_rd_mmc };
wire  [1:0] sd_wr = { sd_wr_plus3 | sd_wr_wd, sd_wr_mmc };

wire        sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din = sd_busy_mmc ? sd_buff_din_mmc : (plus3_fdd_ready ? sd_buff_din_plus3 : sd_buff_din_wd);
wire        sd_buff_wr;
wire  [1:0] img_mounted;
wire [31:0] img_size;

wire        sd_ack_conf;
wire        sd_conf;
wire        sd_sdhc;

wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire        ioctl_download;
wire  [7:0] ioctl_index;


wire osdRs = ~status[0];
wire osdNmi = ~status[1];
wire osdMix = ~status[2];

wire plus3_fdd_ready = 1'b0;

mist_io #(.STRLEN(($size(CONF_STR)>>3))) mist_io
(
	.*,
	.ioctl_ce(1),
	.conf_str(CONF_STR),

	.CONF_DATA0(cfgD0),
	.clk_sys(clock56),
	.SPI_SCK(spiCk),
	.SPI_SS2(spiS2),
	.SPI_DI(spiDi),
	.SPI_DO(spiDo),

	// unused
	.ps2_key(),
	.ps2_mouse(),
	.ps2_mouse_clk(),
	.ps2_mouse_data(),
	.joystick_0(),
	.joystick_1(),
	.joystick_analog_0(),
	.joystick_analog_1()
);

sd_card sd_card
(
    .*,
	.clk_sys(clock56),
    .img_mounted(img_mounted[0]), //first slot for SD-card emulation
    .sd_busy(sd_busy_mmc),
    .sd_rd(sd_rd_mmc),
    .sd_wr(sd_wr_mmc),
    .sd_lba(sd_lba_mmc),
    .sd_buff_din(sd_buff_din_mmc),
    .allow_sdhc(1),
    .sd_cs (spi_cs),
    .sd_sck(spi_ck),
    .sd_sdi(spi_do),
    .sd_sdo(spi_di)
);

osd #(.OSD_X_OFFSET(10'd0), .OSD_Y_OFFSET(10'd0), .OSD_COLOR(3'd4)) Osd
(
	.*,
	.clk_sys(clock56),
	.ce(0),
	.rotate(0),
	.SPI_SCK(spiCk),
	.SPI_SS3(spiS3),
	.SPI_DI(spiDi),

	.R_in(vduRGB[17:12]),
	.G_in(vduRGB[11: 6]),
	.B_in(vduRGB[ 5: 0]),
	.HSync(~vduHs     ),
	.VSync(~vduVs     ),

	.R_out(rgb[17:12] ),
	.G_out(rgb[11: 6] ),
	.B_out(rgb[ 5: 0] )
);

assign sync = ~(vduHs^vduVs);
assign led = ~ioctl_download;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
