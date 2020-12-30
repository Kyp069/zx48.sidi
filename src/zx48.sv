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
	.c1    (co28   ),
	.locked(locked )
);
clockctrl ClockCtrl
(
	.ena   (locked ),
	.inclk (co28   ),
	.outclk(clock28)
);

reg[3:0] ce = 4'b1111;
always @(negedge clock28) ce <= ce+1'd1;

wire ce7M0p = locked & ~ce[0] &  ce[1];
wire ce7M0n = locked & ~ce[0] & ~ce[1];

wire ce3M5p = locked & ~ce[0] & ~ce[1] &  ce[2];
wire ce3M5n = locked & ~ce[0] & ~ce[1] & ~ce[2];

//-------------------------------------------------------------------------------------------------

reg[5:0] rs;
wire powerOn = rs[5];
always @(posedge clock28) if(cc3M5p) if(!rs[5]) rs <= rs+1'd1;

//-------------------------------------------------------------------------------------------------

reg mreqt23iorqtw3;
always @(posedge clock28) if(cc3M5p) mreqt23iorqtw3 <= mreq & ioFE;

reg cpuck;
always @(posedge clock28) if(ce7M0n) cpuck <= !(cpuck && contend);

wire contend = !(vduCn && cpuck && mreqt23iorqtw3 && ((!a[15] && a[14]) || !ioFE));

wire cc3M5p = ce3M5n & contend;
wire cc3M5n = ce3M5p & contend;

//-------------------------------------------------------------------------------------------------

wire reset = powerOn & memOn & keyF11 & osdRs;
wire nmi = keyF5 & osdNmi;

reg mi = 1'b1;
always @(posedge clock28) if(cc3M5p) mi <= vduI;

wire[ 7:0] d;
wire[ 7:0] q;
wire[15:0] a;

cpu Cpu
(
	.clock  (clock28),
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
always @(posedge clock28) if(ce7M0n) if(!ioFE && !wr) { speaker, mic, border } <= q[4:0];

//-------------------------------------------------------------------------------------------------

wire[ 7:0] memQ;
wire[ 7:0] memVQ;
wire[12:0] memVA = vduA;

memory Mem
(
	.clock56(clock56),
	.clock28(clock28),
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
	.clock  (clock28),
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

wire[7:0] psgA1;
wire[7:0] psgB1;
wire[7:0] psgC1;

wire[7:0] psgA2;
wire[7:0] psgB2;
wire[7:0] psgC2;

audio Aud
(
	.clock  (clock28),
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
	.mix    (osdMix ),
	.audio  (audio  )
);

//-------------------------------------------------------------------------------------------------

wire[4:0] keyQ;
wire[7:0] keyA = a[15:8];

keyboard Key
(
	.clock  (clock28),
	.ce     (ce7M0p ),
	.code   (ps2Code),
	.strobe (ps2Strb),
	.pressed(~ps2Prsd),
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
	.clock  (clock28),
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
	.clock  (clock28),
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
	.miso   (spi_di ),
	.mosi   (spi_do )
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

assign led = ~sd_busy;

//-------------------------------------------------------------------------------------------------

localparam CONF_STR = {
	"ZX48;;",
	"T0,Reset;",
	"T1,NMI;",
	"O2,Scandoubler,Off,On;",
	"O34,Scanlines,None,25%,50%,75%;",
	"O5,AY mixer,ACB,ABC;",
	"V,v1.0"
};

wire[31:0] status;
wire[ 7:0] ps2Code;
wire       ps2Strb;
wire       ps2Prsd;
wire       scandoubler_disable;

wire       sd_ack_conf;
wire       sd_conf;
wire       sd_sdhc;
wire       sd_busy;

wire[31:0] sd_lba;
wire[ 1:0] sd_rd;
wire[ 1:0] sd_wr;
wire       sd_ack;
wire[ 8:0] sd_buff_addr;
wire[ 7:0] sd_buff_din;
wire[ 7:0] sd_buff_dout;
wire       sd_buff_wr;
wire       img_readonly;
wire[ 1:0] img_mounted;
wire[31:0] img_size;

wire osdRs = ~status[0];
wire osdNmi = ~status[1];
wire osdMix = ~status[5];

user_io #(.STRLEN(($size(CONF_STR)>>3))) userIo
( 
	.*,
	.conf_str    (CONF_STR),
	.clk_sys     (clock28 ),
	.clk_sd      (clock28 ),
	.SPI_CLK     (spiCk   ),
	.SPI_SS_IO   (cfgD0   ),
	.SPI_MISO    (spiDo   ),
	.SPI_MOSI    (spiDi   ),
	.status      (status  ),
	.key_code    (ps2Code ),
	.key_strobe  (ps2Strb ),
	.key_pressed (ps2Prsd ),
	.key_extended(        ),
	.scandoubler_disable(scandoubler_disable),

	.sd_conf(0),
	.sd_sdhc(1),
	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_din(sd_buff_din),
	.sd_din_strobe(),
	.sd_dout(sd_buff_dout),
	.sd_dout_strobe(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_size(img_size),

	.conf_chr(),
	.conf_addr(),
	.ps2_kbd_clk(),
	.ps2_kbd_data(),
	.ps2_mouse_clk(),
	.ps2_mouse_data(),
	.mouse_x(),
	.mouse_y(),
	.mouse_z(),
	.mouse_idx(),
	.mouse_flags(),
	.mouse_strobe(),
	.serial_data(),
	.serial_strobe(),
	.joystick_0(),
	.joystick_1(),
	.joystick_2(),
	.joystick_3(),
	.joystick_4(),
	.joystick_analog_0(),
	.joystick_analog_1(),
	.buttons(),
	.switches(),
	.ypbpr(),
	.no_csync(),
	.core_mod(),
	.rtc()
);

mist_video mistVideo
(
	.clk_sys     (clock28    ),
	.SPI_SCK     (spiCk      ),
	.SPI_DI      (spiDi      ),
	.SPI_SS3     (spiS3      ),
	.scanlines   (status[4:3]),
	.ce_divider  (1'b0       ),
	.no_csync    (1'b0       ),
	.ypbpr       (1'b0       ),
	.rotate      (2'b00      ),
	.blend       (1'b0       ),
	.R           (vduRGB[17:12]),
	.G           (vduRGB[11: 6]),
	.B           (vduRGB[ 5: 0]),
	.HSync       (~vduHs     ),
	.VSync       (~vduVs     ),
	.VGA_R       (rgb[17:12] ),
	.VGA_G       (rgb[11: 6] ),
	.VGA_B       (rgb[ 5: 0] ),
	.VGA_VS      (sync[1]    ),
	.VGA_HS      (sync[0]    ),
	.scandoubler_disable(scandoubler_disable)
);

sd_card sdCard
(
	.*,
	.clk_sys   (clock28 ),
    .sd_cs     (spi_cs  ),
    .sd_sck    (spi_ck  ),
    .sd_sdi    (spi_do  ),
    .sd_sdo    (spi_di  ),
	.allow_sdhc(1       ),
	.sd_rd     (sd_rd[0]),
	.sd_wr     (sd_wr[0]),
	.img_mounted(img_mounted[0])
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
