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
output reg ack_error

`ifdef DEBUG 
,
output reg sda_r,
output reg scl_r,
output reg [8:0] iic_clk_cnt,
output reg sda_dir,
output reg [3:0] cs,
output reg [3:0] ns,
output reg rd_trig_r,
output reg wr_trig_r,
output reg [7:0] db_r,
output reg [7:0] read_data,
output reg [3:0] num,				//count the address or data bit number
output reg scl_en
`endif
);
`ifndef DEBUG
reg sda_r;
reg scl_r;
reg [8:0] iic_clk_cnt;
reg sda_dir;				//1:output, 0:tri-state
reg [3:0] cs;
reg [3:0] ns;
reg rd_trig_r;
reg wr_trig_r;
reg [7:0] db_r;		//在IIC上传送的数据寄存器
reg [7:0] read_data;	//读出EEPROM的数据寄存器
reg [3:0] num;
reg scl_en;
`endif
assign sda=(sda_dir)?sda_r:1'bz;
assign scl=scl_r;
parameter CLK_100K_RISE=9'd0, CLK_100K_HCNTR=9'd124,CLK_100K_FALL=9'd249,  CLK_100K_LCNTR=9'd374;
`define SCL_RIS		(iic_clk_cnt==CLK_100K_RISE)		//上升沿
`define SCL_HIG		(iic_clk_cnt==CLK_100K_HCNTR)		//高電平中點
`define SCL_FAL		(iic_clk_cnt==CLK_100K_FALL)		//下降沿
`define SCL_LOW		(iic_clk_cnt==CLK_100K_LCNTR)		//低電平中點
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
	else if (`SCL_RIS) scl_r<=1;
	else if (`SCL_FAL) scl_r<=0;
end	
assign scl=scl_r;
	
always @(posedge clk_50M, negedge rstn)
begin
	if (~rstn) begin rd_trig_r<=0; wr_trig_r<=0; end
	else begin
			if (~rd_trig) rd_trig_r<=1'b1;
			else if (cs==STOP) rd_trig_r<=1'b0;
			if (~wr_trig) wr_trig_r<=1'b1;
			else if (cs==STOP) wr_trig_r<=1'b0;
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
			end
	DATA_TX: if ((num==4'd8) && (`SCL_LOW)) ns=ACK4; else ns=DATA_TX;
	ACK4: if (`SCL_LOW) ns=STOP;
	STOP: if (`SCL_LOW) ns=IDLE;
	START2: if (`SCL_LOW) ns=DEV_ADD_R;
	DEV_ADD_R: if ((num==4'd8) && (`SCL_LOW)) ns=ACK5; else ns=DEV_ADD_R;
	ACK5: if (ack_error) ns=STOP; else if (`SCL_LOW) ns=DATA_RX; else ns=ACK5;
	DATA_RX: if ((num==4'd8) && (`SCL_LOW)) ns=ACK6; else ns=DATA_RX;
	ACK6: if (`SCL_LOW) ns=STOP;
	default: if (`SCL_LOW) ns=IDLE;
	endcase

end
assign sda=(sda_dir)?sda_r:1'bz;
always @(posedge clk_50M, negedge rstn)
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
				db_r<=`DEVICE_WRITE;
				if (`SCL_HIG) 	sda_r<=0;
			  end
	DEV_ADD_W: begin
					scl_en<=1;
					busy<=1;
					sda_dir<=1;
					if (`SCL_LOW) 
						begin 
							sda_r<=db_r[7];
							db_r<={db_r[6:0],1'b0};
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
				  if (`SCL_LOW) 
						begin 
							sda_r<=db_r[7];
							db_r<={db_r[6:0],1'b0};
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
				  if (`SCL_LOW) 
						begin 
							sda_r<=db_r[7];
							db_r<={db_r[6:0],1'b0};
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
				  if (`SCL_LOW) 
						begin 
							sda_r<=db_r[7];
							db_r<={db_r[6:0],1'b0};
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
				sda_dir=1;
				if (`SCL_HIG) sda_r<=1'b1;
			end
	START2: begin
				scl_en<=1;
				busy<=1;
				sda_r<=1;			//sda output
				sda_dir<=1;
				db_r<=`DEVICE_READ;
				if (`SCL_HIG) 	sda_r<=0;
			  end				
	DEV_ADD_R: begin
					scl_en<=1;
					busy<=1;
					sda_dir<=1;
					if (`SCL_LOW) 
						begin 
							sda_r<=db_r[7];
							db_r<={db_r[6:0],1'b0};
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


