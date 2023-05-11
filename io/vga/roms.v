module roms(VGA_BLANK_N, clk, ps2_clk, ps2_data, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0, LEDR, vga_clk, vga_data,h_addr,v_addr);
input clk;
input ps2_clk;
input ps2_data;
input vga_clk;
input VGA_BLANK_N;
input [9:0]h_addr;
input [9:0]v_addr;
output reg [23:0] vga_data;
output [6:0]HEX5;
output [6:0]HEX4;
output [6:0]HEX3;
output [6:0]HEX2;
output [6:0]HEX1;
output [6:0]HEX0;
output LEDR;
integer x;
integer y;
integer xnei;
integer ynei;
integer index;
integer asc;
wire ovfl;
wire [7:0] data;
wire ready;
(* ram_init_file = "char_rom.mif" *) reg [11:0] dianzhen [4095:0];
reg [7:0] xiancun [1919: 0];
(* ram_init_file = "rom1port.mif" *) reg [7:0] ram [255:0];
(* ram_init_file = "rom2port.mif" *) reg [7:0] rambig [255:0];
reg [10:0] line [29:0];
reg [7:0] count;
reg [7:0] effdata;
reg nextdata_n;
reg state;
reg capslock;
reg shiftlock;
reg [9:0] counth;
reg [9:0] countv;
reg [6:0] countx;
reg [10:0] county;
reg [7:0] ascii;
reg [11:0] dianzhen_line;
initial 
begin
vga_data = 0;
x = 0;
y = 0;
xnei = 0;
ynei = 0;
index = 0;
asc = 0;
counth = 0;
countv = 0;
countx = 0;
county = 0;
ascii = 0;
dianzhen_line = 0;
effdata = 0;
capslock = 0;
shiftlock = 0;
state = 0;
count = 0;
counth = 0;
countv = 0;
xiancun[0]=8'h24;
end
always @ (posedge clk)
begin
	if(ready==1)
	begin
		if(data == 8'h58)
		begin
			if(state == 0 && capslock == 0)
			begin
				capslock = 1;
			end
			else if(state == 1 && capslock == 0)
			begin
				capslock = 0;
			end
			else if(state == 1 && capslock == 1)
			begin
				capslock = 1;
			end
			else if(state == 0 && capslock == 1)
			begin
				capslock = 0;
			end
		end
		if(data == 8'h12 || data == 8'h59)
		begin
			if(state == 0 && shiftlock == 0)
			begin
				shiftlock = 1;
			end
			else if(state == 1 && shiftlock == 0)
			begin
				shiftlock = 1;
			end
			else if(state == 1 && shiftlock == 1)
			begin
				shiftlock = 0;
			end
			else if(state == 0 && shiftlock == 1)
			begin
				shiftlock = 0;
			end
		end
		if((data != 8'b11110000)&&(state == 0))
		begin
			if(data == 8'h58||data==8'h12||data==8'h59||data==8'h66||data==8'h5a)
			begin
				if(data == 8'h66)
				begin
					xiancun[(county<<6) + countx] = 0;
					if(countx > 0)
					 countx = countx - 1;
					else
					begin
					if(county>0)
					begin
						county =  county - 1;
						countx = line[county];
					end
					end
				end
				else if(data == 8'h5a)
				begin
					line[county] = countx;
					counth=0;
					county =
					county + 1;	
					countx =0;
					xiancun[(county<<6) + countx] = 8'h24;
				end
			end
			else
			begin
			effdata = data;
			count = count + 1;
			if(counth<576)
			begin 
				countx = countx + 1;
				counth = counth + 9;
			end
			else
			begin
				line[county] = countx;
				counth = 0;
				countx = 0;
				if(countv < 480)
				begin
					county = county + 1;
					countv = countv + 16;
				end
			end
			if(shiftlock==1)
			begin
			case(data)
			8'h0E:ascii=8'h7E;
			8'h16:ascii=8'h21;
			8'h1E:ascii=8'h40;
			8'h26:ascii=8'h23;
			8'h25:ascii=8'h24;
			8'h2E:ascii=8'h25;
			8'h36:ascii=8'h5E;
			8'h3D:ascii=8'h26;
			8'h3E:ascii=8'h2A;
			8'h46:ascii=8'h28;
			8'h45:ascii=8'h29;
			8'h4E:ascii=8'h5F;
			8'h55:ascii=8'h2B;
			8'h5D:ascii=8'h7C;
			default:
			begin
			if(capslock==1)
			begin
				ascii =data[data];
			end
			else
			begin
				ascii = rambig[data];
			end
			end
			endcase
			end
			else
			begin
			if(capslock==0)
			begin
				ascii = ram[data];
			end
			else
			begin
				ascii = rambig[data];
			end
			end
			xiancun[(county<<6) + countx] = ascii;
			end
		end
		else if((data == 8'b11110000)&&(state == 0))
		begin
			effdata = data;
			state = 1;
		end
		else if((data != 8'b11110000)&&(state == 1))
		begin
			state = 0;
			effdata = 8'b11110000;
		end
		nextdata_n=0;
		end
	end
ps2_keyboard pk(clk, 1, ps2_clk, ps2_data, data, ready, nextdata_n, ovfl);
abouthex ah(state, count, effdata, ascii, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0);
lock lk(shiftlock, capslock, LEDR);
reg count_clk=0;
reg [25:0] counter=0;
always @(posedge clk)
begin
	if (counter == 24999999) 
	begin
		count_clk <= ~count_clk;
		counter <= 0;
	end
	else
		counter <= counter + 1;
end
reg flag;
always @ (posedge vga_clk)
begin
	if(h_addr >= 0 && h_addr < 576)
	begin
		y =  v_addr[8:4];
		ynei =  v_addr[3:0];
		if(countx==x&&county==y)
			flag=1;
		else
			flag=0;
		asc = xiancun[(y << 6) + x];
		index = (asc << 4) + ynei;
		dianzhen_line = dianzhen[index];
		if(dianzhen_line[xnei]||(flag==1&&xnei==8&&count_clk==0))
		vga_data = 24'hffffff;
		else
		vga_data = 24'h000000;
	end
	else
		vga_data = 24'h000000;
	if(VGA_BLANK_N)
	begin
		if(xnei == 8)
		begin
			x = x + 1;
			xnei = 0;
		end
		else
			xnei = xnei + 1;
		if(x == 64)
			x = 0;
		else
			x = x;
	end
	else 
	begin
		x=0;
		xnei=0;
	end
end
endmodule
