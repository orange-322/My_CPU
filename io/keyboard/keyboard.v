module keyboard(input clk,
	input clrn,
	input ps2_clk,
	input ps2_data,
	output Shift_LED,
	output Ctrl_LED,
	output Caps_LED,
	output [6:0] result0,
	output [6:0] result1,
	output [6:0] result2,
	output [6:0] result3,
	output [6:0] result4,
	output [6:0] result5);
	reg shift_state;
	reg ctrl_state=0;
	reg [1:0] state=0;
	reg [1:0] Caps_state=0;
	reg Caps=0;
	reg [7:0] cur_key;
	reg [7:0] key_count=0;
   reg [2:0]temp_count;
	reg [7:0] Store[7:0];
	reg [2:0] point;
   wire nextdata_n;
	reg [7:0] temp_ascii;
   wire [7:0] data;
   wire ready;
   wire overflow;
	reg  [7:0] ascii_key;
	wire [7:0] s_ascii_key;
	wire [7:0] b_ascii_key;
	wire [6:0] temp_result0;
	wire [6:0] temp_result1;
	wire [6:0] temp_result2;
	wire [6:0] temp_result3;
rom1port my_rom1(
	.address(cur_key),
	.clock(clk),
	.q(s_ascii_key));
rom2port my_rom2(
	.address(cur_key),
	.clock(clk),
	.q(b_ascii_key));
ps2_keyboard mykey(clk, clrn, ps2_clk, ps2_data, data, ready, nextdata_n, overflow);
always@(posedge clk)
begin
	if(Caps_state==2'b01||Caps_state==2'b10) 
		Caps<=1;
	else 
		Caps<=0;
	if(shift_state)
	begin
		case(cur_key)
		8'h0E:ascii_key<=8'h7E;
		8'h16:ascii_key<=8'h21;
		8'h1E:ascii_key<=8'h40;
		8'h26:ascii_key<=8'h23;
		8'h25:ascii_key<=8'h24;
		8'h2E:ascii_key<=8'h25;
		8'h36:ascii_key<=8'h5E;
		8'h3D:ascii_key<=8'h26;
		8'h3E:ascii_key<=8'h2A;
		8'h46:ascii_key<=8'h28;
		8'h45:ascii_key<=8'h29;
		8'h4E:ascii_key<=8'h5F;
		8'h55:ascii_key<=8'h2B;
		8'h5D:ascii_key<=8'h7C;
		default:
		begin
			if(Caps)
				ascii_key<=s_ascii_key;
			else 
				ascii_key<=b_ascii_key;
		end
		endcase
	end
	else 
	begin
		if(Caps)
			ascii_key<=b_ascii_key;
		else
			ascii_key<=s_ascii_key;
	end
    if(!clrn)
	 begin 
	 state<=0;key_count<=0;cur_key<=0;temp_count<=0;Store[0]<=0;Store[1]<=0;Store[2]<=0;Store[3]<=0;Store[4]<=0;Store[5]<=0;Store[6]<=0;Store[7]<=0;shift_state<=0;ctrl_state<=0;Caps_state<=0;state<=0;
	 end
	else begin
		if(ready)begin
			case(state)
			0:begin 
			cur_key<=data;
		   state<=1;
			key_count<=key_count+1;
			Store[point]<=data;
			temp_count<=temp_count+1;
			point<=point+1;
			if(data==8'h14) 
				ctrl_state<=1;
			else if(data==8'h12)
				shift_state<=1;
			else if(data==8'h58&&Caps_state==2'b00)
				Caps_state<=2'b01;
			else if(data==8'h58&&Caps_state==2'b10)
				Caps_state<=2'b11;
			end
			1:begin
			if(data==8'hf0)
				state<=2;
			else
				begin
				if(data!=Store[point-1])
					begin
						if(data==8'h14)
							ctrl_state<=1;
						else if(data==8'h12)
							shift_state<=1;
						else if(data==8'h58&&Caps_state==2'b00)
							Caps_state<=2'b01;
						else if(data==8'h58&&Caps_state==2'b10)
							Caps_state<=2'b11;
						else 
						begin
						cur_key<=data;
						Store[point]<=data;
						temp_count<=temp_count+1;
						point<=point+1;
						key_count<=key_count+1;
						end
					end
				end
			end
			2:begin
			temp_count=temp_count-1;
			point=point-1;
			if(temp_count==0)
			begin
				Store[0]<=0;
				cur_key=0;
				state<=0;
				if(data==8'h14)
					ctrl_state<=0;
				else if(data==8'h12)
					shift_state<=0;
				else if(data==8'h58&&Caps_state==2'b01)
					Caps_state<=2'b10;
				else if(data==8'h58&&Caps_state==2'b11)
					Caps_state<=2'b00;
				end
			else 
			begin
				if(data==8'h14)
				begin 
				ctrl_state<=0;state<=1;
				end
				else if(data==8'h12)
				begin
				shift_state<=0;state<=1;
				end
				else if(data==8'h58&&Caps_state==2'b01)
				begin 
				Caps_state<=2'b10;state<=1;
				end
				else if(data==8'h58&&Caps_state==2'b11)
				begin 
				Caps_state<=2'b00;state<=1;
				end
				else 
				begin
				if(data==Store[point]&&shift_state==0)
				begin
					Store[point]<=0;
					state<=1;
					cur_key=0;
				end
				else if(data==Store[point]&&shift_state==1)
				begin
					Store[point]<=0;
					point<=point+1;
					state<=1;
					cur_key=0;
				end
				else 
				begin 
				point<=point+1;
				state<=1;
				end
				end
			end
			end
			endcase
		end
	end	
end
assign nextdata_n=~ready;	
assign Shift_LED=shift_state;
assign Ctrl_LED=ctrl_state;
assign Caps_LED=Caps;
bcd7seg i0(.b(cur_key[3:0]),.h(temp_result0));
bcd7seg i1(.b(cur_key[7:4]),.h(temp_result1));
bcd7seg i2(.b(ascii_key[3:0]),.h(temp_result2));
bcd7seg i3(.b(ascii_key[7:4]),.h(temp_result3));
bcd7seg i4(.b(key_count[3:0]),.h(result4));
bcd7seg i5(.b(key_count[7:4]),.h(result5));
assign result0=cur_key==0?7'b1111111:temp_result0;
assign result1=cur_key==0?7'b1111111:temp_result1;
assign result2=cur_key==0?7'b1111111:temp_result2;
assign result3=cur_key==0?7'b1111111:temp_result3;
endmodule


module ps2_keyboard(clk,clrn,ps2_clk,ps2_data,data,ready,nextdata_n,overflow);
    input clk,clrn,ps2_clk,ps2_data;
	input nextdata_n;
    output [7:0] data;
    output reg ready;
    output reg overflow;     
    reg [9:0] buffer;       
    reg [7:0] fifo[7:0];
	 reg [2:0] w_ptr,r_ptr;
    reg [3:0] count;  
    reg [2:0] ps2_clk_sync;
    always @(posedge clk) begin
        ps2_clk_sync <=  {ps2_clk_sync[1:0],ps2_clk};
    end

    wire sampling = ps2_clk_sync[2] & ~ps2_clk_sync[1];
    
    always @(posedge clk) begin
        if (clrn == 0) begin 
            count <= 0; w_ptr <= 0; r_ptr <= 0; overflow <= 0; ready<= 0;
        end 
		else if (sampling) begin
            if (count == 4'd10) begin
                if ((buffer[0] == 0) && 
                    (ps2_data)       &&  
                    (^buffer[9:1])) begin   
                    fifo[w_ptr] <= buffer[8:1]; 
                    w_ptr <= w_ptr+3'b1;
                    ready <= 1'b1;
                    overflow <= overflow | (r_ptr == (w_ptr + 3'b1));
                end
                count <= 0;    
            end else begin
                buffer[count] <= ps2_data; 
                count <= count + 3'b1;
            end      
        end
        if ( ready ) begin 
				if(nextdata_n == 1'b0) 
				begin
				   r_ptr <= r_ptr + 3'b1; 
					if(w_ptr==(r_ptr+1'b1)) 
					     ready <= 1'b0;
				end           
        end
    end

    assign data = fifo[r_ptr];
endmodule 

module scancode_ram(clk, addr,outdata);
input clk;
input [7:0] addr;
output reg [7:0] outdata;
reg [7:0] ascii_tab[255:0];

always @(posedge clk)
begin
      outdata <= ascii_tab[addr];
end

endmodule

module bcd7seg(
	 input  [3:0] b,
	 output reg [6:0] h
	 );
	 always@(*)
	 begin
		case(b)
		4'h0:h=7'b1000000;
		4'h1:h=7'b1111001;
		4'h2:h=7'b0100100;
		4'h3:h=7'b0110000;
		4'h4:h=7'b0011001;
		4'h5:h=7'b0010010;
		4'h6:h=7'b0000010;
		4'h7:h=7'b1111000;
		4'h8:h=7'b0000000;
		4'h9:h=7'b0010000;
		4'ha:h=7'b0001000;
		4'hb:h=7'b0000011;
		4'hc:h=7'b1000110;
		4'hd:h=7'b0100001;
		4'he:h=7'b0000110;
		4'hf:h=7'b0001110;
		endcase
	end
endmodule	