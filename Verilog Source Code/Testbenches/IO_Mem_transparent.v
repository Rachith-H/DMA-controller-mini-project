`timescale 1ns / 1ps

module IO_Mem_Transparent;
reg dreq, rdy, hlda, bg, rst, regw, clk;
reg [1:0] regsel;
reg [7:0] data_in;
reg [15:0] setup;
wire hld, dack, memw, memr, ior, iow, eop;
wire [15:0] addrbus;
wire [7:0] data_out;

DMAC uut (
    .HLDA(hlda),
    .DREQ(dreq),
    .BG(bg),
    .RST(rst),
    .CLK(clk),
    .RDY(rdy),
    .REGW(regw),
    .REGSEL(regsel),
    .HLD(hld),
    .DACK(dack),
    .MEMW(memw),
    .MEMR(memr),
    .IOR(ior),
    .IOW(iow),
    .EOP(eop),
    .Addrbus(addrbus),
    .Setup(setup),
    .Data_in(data_in),
    .Data_out(data_out)
);

integer i=5;

always #3 clk = ~clk;

always begin
    #20 data_in = i;
    i = i+5;
end

initial begin 
    clk = 0;
    rst = 1; #4;
    rst = 0;
    hlda = 0;
    bg=0;
    dreq = 1; #8;
    regw = 1; #6;
    regsel = 2'b00;
    setup = 16'h0089; #6;
    regsel = 2'b01;
    setup = 16'h0003; #6;
    regsel = 2'b11;
    setup = 16'h0001; #5;
    regw = 0;
    rdy = 1;
    bg = 1;
    #120 bg = 0;
    #40 bg = 1;
end

always@(*) begin
    if(eop) begin
     dreq = 0 ;
     rdy = 0;
     bg = 0;
     end
end

initial  #250 $finish;

endmodule

