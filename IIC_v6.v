//v6: sw按壓固定位置已經讀寫正確，只是有glitch
//v5: return to v1 because of statemachine problem
//v1: integrate arduino
//v0: initial for debug
//`define DEBUG
`timescale 1ns/1ns
module IIC(
input clk_50M,
input rstn,
inout sda,
output scl,
input rd_trig,
input wr_trig,
output reg busy,
output reg ack_error,
//output reg [7:0] db_r,
output reg [3:0] cs,
output led,
output reg [3:0] num
//output reg rd_trig_r,
//output reg wr_trig_r,
//output reg [8:0] iic_clk_cnt,
//output reg scl_en
`ifdef DEBUG 
,
output reg sda_r,
output reg scl_r,
output reg [8:0] iic_clk_cnt,
output reg sda_dir,
//output reg [3:0] cs,
output reg [3:0] ns,
output reg rd_trig_r,
output reg wr_trig_r,
output reg [7:0] db_r,
output reg [7:0] read_data,
//output reg [3:0] num				//count the address or data bit number
output reg scl_en
`endif
);
`ifndef DEBUG
reg sda_r;
reg scl_r;
reg [8:0] iic_clk_cnt;
reg sda_dir;				//1:output, 0:tri-state
//reg [3:0] cs;
reg [3:0] ns;
reg rd_trig_r;
reg wr_trig_r;
reg [7:0] db_r;		//在IIC上传送的数据寄存器
reg [7:0] read_data;	//读出EEPROM的数据寄存器
//reg [3:0] num;
reg scl_en;
`endif
reg led_r;
reg [23:0] led_cnt;
wire wr_trig_db1;
reg wr_trig_db2;
reg wr_trig_db3;
reg wr_trig_db;
debounce db0(
    .clk(clk_50M),         // 系統時鐘
    .rst_n(rstn),      // 低有效重置
    .button_in(wr_trig),   // 輸入按鈕信號
    .button_out(wr_trig_db1)    // 去抖後的按鈕信號
);
always @(posedge clk_50M, negedge rstn)
begin
	if (~rstn) begin wr_trig_db<=1'b0;wr_trig_db2<=1'b1; wr_trig_db3<=1'b1; end
	else  begin
				wr_trig_db2<=wr_trig_db1;
				wr_trig_db3<=wr_trig_db2;
				wr_trig_db<=(~wr_trig_db1) & (wr_trig_db3);
			end
end
wire rd_trig_db1;
reg rd_trig_db2;
reg rd_trig_db3;
reg rd_trig_db;
debounce db1(
    .clk(clk_50M),         // 系統時鐘
    .rst_n(rstn),      // 低有效重置
    .button_in(rd_trig),   // 輸入按鈕信號
    .button_out(rd_trig_db1)    // 去抖後的按鈕信號
);
always @(posedge clk_50M, negedge rstn)
begin
	if (~rstn) begin rd_trig_db<=1'b0;rd_trig_db2<=1'b1; rd_trig_db3<=1'b1; end
	else  begin
				rd_trig_db2<=rd_trig_db1;
				rd_trig_db3<=rd_trig_db2;
				rd_trig_db<=(~rd_trig_db1) & (rd_trig_db3);
			end
end
assign sda=(sda_dir)?sda_r:1'bz;
assign scl=scl_r;
parameter CLK_100K_RISE=9'd0, CLK_100K_HCNTR=9'd124,CLK_100K_FALL=9'd249,  CLK_100K_LCNTR=9'd374;
`define SCL_RIS		(iic_clk_cnt==CLK_100K_RISE)		//上升沿
`define SCL_HIG		(iic_clk_cnt==CLK_100K_HCNTR)		//高電平中點
`define SCL_START2_INTERVAL	(iic_clk_cnt>CLK_100K_HCNTR) && 	(iic_clk_cnt<CLK_100K_LCNTR)	//高電平中點之后,狀態結束之前
`define SCL_STOP_INTERVAL		((iic_clk_cnt>CLK_100K_HCNTR+9'd1) && (iic_clk_cnt<CLK_100K_LCNTR+9'b1))//為了讓stop的sda拉高直至IDEL，需在高電平中點之後也就是在count 大于125，小於375
`define SCL_FAL		(iic_clk_cnt==CLK_100K_FALL)		//下降沿
`define SCL_LOW		(iic_clk_cnt==CLK_100K_LCNTR)		//低電平中點
`define SCL_LOW_PLUS1		(iic_clk_cnt==CLK_100K_LCNTR+1)		//低電平中點,如果不多加1，會多數一個MSB　bit

//`define SCL_GT_LOW	(iic_clk_cnt>CLK_100K_LCNTR+9'd4)		//大於低電平中點后,加幾個clk保險
`define	DEVICE_READ		8'b1010_0001	//被寻址器件地址（读操作）
`define DEVICE_WRITE	8'b1010_0000	//被寻址器件地址（写操作）
`define	WRITE_DATA		8'b1101_0001	//写入EEPROM的数据
`define WORD_ADDRL		8'b0001_0011	//写入/读出EEPROM的地址寄存器
`define WORD_ADDRH		8'b0100_1000	//写入/读出EEPROM的地址寄存器	

parameter 	IDLE 	= 4'd0;
parameter 	START1 	= 4'd1;
parameter 	DEV_ADD_W 	= 4'd2;
parameter 	ACK1 	= 4'd3;
parameter 	WORD_ADDH 	= 4'd4;
parameter 	ACK2 	= 4'd5;
parameter 	WORD_ADDL 	= 4'd6;
parameter 	ACK3	= 4'd7;
parameter 	DATA_TX 	= 4'd8;
parameter 	ACK4	= 4'd9;
parameter 	START2 	= 4'd10;
parameter 	DEV_ADD_R 	= 4'd11;
parameter 	ACK5	= 4'd12;
parameter 	DATA_RX 	= 4'd13;
parameter 	ACK6 	= 4'd14;
parameter 	STOP 	= 4'd15;
assign led=led_r;
always @(posedge clk_50M, negedge rstn)
begin
	if (~rstn) led_r<=1'b0;
	else if (led_cnt==24'd0) 
		  begin 
			led_r=~led_r; 
			led_cnt=led_cnt+24'd1; 
		  end
		  else led_cnt=led_cnt+24'd1;
end

always @(posedge clk_50M, negedge rstn)
begin
	if (~rstn) iic_clk_cnt<=0;
	else if (scl_en) 
			begin
				if (iic_clk_cnt==9'd499) iic_clk_cnt<=0;
				else iic_clk_cnt<=iic_clk_cnt+9'd1;
			end 
end

always @(posedge clk_50M, negedge rstn)
begin
	if (~rstn) scl_r<=1; 
	else if (cs==IDLE) scl_r<=1;
	//else if (cs==STOP && `SCL_LOW) scl_r<=1;
	else if (`SCL_RIS) scl_r<=1;
	else if (!(cs==STOP)) begin if (`SCL_FAL) scl_r<=0;end		//stop狀況特殊，在·SCL_LOW上升后不再下降，故排除
end	
assign scl=scl_r;
	
always @(posedge clk_50M, negedge rstn)
begin
	if (~rstn) begin rd_trig_r<=0; wr_trig_r<=0; end
	else begin
			if (rd_trig_db) rd_trig_r<=1'b1;
			else if (cs==STOP || cs==IDLE) rd_trig_r<=1'b0;
			if (wr_trig_db) wr_trig_r<=1'b1;
			else if (cs==STOP || cs==IDLE) wr_trig_r<=1'b0;
		  end
end
always @(posedge clk_50M, negedge rstn)
begin
	if (~rstn) cs<=IDLE;
	else cs<=ns;
end

always @(*)
begin
	case (cs)
	IDLE: if (wr_trig_r ||rd_trig_r) ns= START1; else ns=IDLE;
	START1: if (`SCL_HIG) ns=DEV_ADD_W; else ns=START1;
	//START1: if (iic_clk_cnt==9'd124) ns=DEV_ADD_W; else ns=START1;
	DEV_ADD_W: if ((num==4'd8) && (`SCL_LOW)) ns=ACK1; else ns=DEV_ADD_W;
	ACK1: if (ack_error && (`SCL_LOW)) ns=STOP; else if (`SCL_LOW) ns=WORD_ADDH; else ns=ACK1;
	WORD_ADDH: if ((num==4'd8) && (`SCL_LOW)) ns=ACK2; else ns=WORD_ADDH;
	ACK2: if ((ack_error) && (`SCL_LOW)) ns=STOP; else if (`SCL_LOW) ns=WORD_ADDL; else ns=ACK2;
	WORD_ADDL: if ((num==4'd8) && (`SCL_LOW)) ns=ACK3; else ns=WORD_ADDL;
	ACK3: begin
				if (`SCL_LOW) 
				begin if (ack_error) ns=STOP;
						else if (wr_trig_r) ns=DATA_TX;
						else if (rd_trig_r) ns=START2;
				end
				else ns=ACK3;
			end
	DATA_TX: if ((num==4'd8) && (`SCL_LOW)) ns=ACK4; else ns=DATA_TX;
	ACK4: if (`SCL_LOW) ns=STOP; else ns=ACK4;
	STOP: if (`SCL_LOW) ns=IDLE; else ns=STOP;
	START2: if (`SCL_HIG) ns=DEV_ADD_R; else ns=START2;//bug here if (`SCL_HIG)
	DEV_ADD_R: if ((num==4'd8) && (`SCL_LOW)) ns=ACK5; else ns=DEV_ADD_R;
	ACK5: if (ack_error) ns=STOP; else if (`SCL_LOW) ns=DATA_RX; else ns=ACK5;
	DATA_RX: if ((num==4'd8) && (`SCL_LOW)) ns=ACK6; else ns=DATA_RX;
	ACK6: if (`SCL_LOW) ns=STOP; else ns=ACK6;
	default: if (`SCL_LOW) ns=IDLE;
	endcase

end
assign sda=(sda_dir)?sda_r:1'bz;
always @(posedge clk_50M)
begin
	case (cs)
	IDLE: begin
				scl_en<=0;
				//wr_trig_r<=0;
				//rd_trig_r<=0;
				busy<=0;
				sda_r<=1;
				sda_dir<=0;			//tri-state
				ack_error<=0;
				num<=0;
				db_r<=0;
				read_data<=0;
			end
	START1: begin
				scl_en<=1;
				busy<=1;
				sda_r<=1;			//sda output
				sda_dir<=1;
				ack_error<=0;
				num<=0;
				db_r<=`DEVICE_WRITE;
				if (`SCL_HIG) 	sda_r<=0;
			  end
	DEV_ADD_W: begin
					scl_en<=1;
					busy<=1;
					sda_dir<=1;
					ack_error<=0;					
					if (`SCL_LOW) 
						begin 
							sda_r<=db_r[7-num];
							//db_r<={db_r[6:0],1'b0};
							num<=num+1;
						end
				  end
	ACK1: begin
				scl_en<=1;
				busy<=1;
				sda_dir<=0;
				if (`SCL_RIS) ack_error<=sda;	
				db_r<=`WORD_ADDRH;
				num<=0;
			end
	WORD_ADDH:begin
				  scl_en<=1;
				  busy<=1;
				  sda_dir<=1;
				  ack_error<=0;
				  if (`SCL_LOW_PLUS1) 
						begin 
							sda_r<=db_r[7-num];
							//db_r<={db_r[6:0],1'b0};
							num<=num+1;
						end
				 end
	ACK2: begin
				scl_en<=1;
				busy<=1;
				sda_dir<=0;
				if (`SCL_RIS) ack_error<=sda;	
				db_r<=`WORD_ADDRL;
				num<=0;
			end
	WORD_ADDL:begin
				  scl_en<=1;
				  busy<=1;	
				  sda_dir<=1;
				  ack_error<=0;
				  if (`SCL_LOW_PLUS1) 
						begin 
							sda_r<=db_r[7-num];
							//db_r<={db_r[6:0],1'b0};
							num<=num+1;
						end
				 end
	ACK3: begin
				scl_en<=1;
				busy<=1;
				sda_dir<=0;
				if (`SCL_RIS) ack_error<=sda;	
				if (wr_trig_r) db_r<=`WRITE_DATA;
				num<=0;
			end
	DATA_TX: begin
				  scl_en<=1;
				  busy<=1;
				  sda_dir<=1;
				  ack_error<=0;
				  if (`SCL_LOW_PLUS1) 
						begin 
							sda_r<=db_r[7-num];
							//db_r<={db_r[6:0],1'b0};
							num<=num+1;
						end
				end
	ACK4:	begin
				scl_en<=1;
				busy<=1;
				sda_dir<=0;
				if (`SCL_RIS) ack_error<=sda;	
				num<=0;
			end
	STOP: begin
				scl_en<=1;
				busy<=0;
				sda_dir<=1;
				sda_r<=1'b0;		//一開始是0，在高電平中點后拉高為1
				if (`SCL_STOP_INTERVAL) sda_r<=1'b1; 
			end
	START2: begin
				scl_en<=1;
				busy<=1;
				sda_r<=1'b1;			//sda output
				sda_dir<=1'b1;
				ack_error<=0;
				db_r<=`DEVICE_READ;
				if (`SCL_HIG) 	sda_r<=0;
			  end				
	DEV_ADD_R: begin
					scl_en<=1;
					busy<=1;
					sda_dir<=1;
					ack_error<=0;
					if (`SCL_LOW) 
						begin 
							sda_r<=db_r[7-num];
							//db_r<={db_r[6:0],1'b0};
							num<=num+1;
						end
					end
	ACK5:	begin
				scl_en<=1;
				busy<=1;
				sda_dir<=0;
				if (`SCL_RIS) ack_error<=sda;	
				num<=0;
			end
	DATA_RX: begin
					scl_en<=1;
					busy<=1;
					sda_dir<=0;
					ack_error<=0;
					if (`SCL_RIS) 
					begin
						read_data<=(read_data<<1);
						read_data[0]<=sda;
						num<=num+1;
					end
				end
	ACK6: begin
				scl_en<=1;
				busy<=1;
				sda_dir<=0;
				if (`SCL_RIS) ack_error<=sda;	
				num<=0;
			end
	default: begin 				
					scl_en<=0;
					busy<=0;
					sda_r<=1;
					sda_dir<=0;			//tri-state
					ack_error<=0;
					num<=0;
					//db_r<=0;
					//read_data<=0;
				end
	endcase			
end					

endmodule


