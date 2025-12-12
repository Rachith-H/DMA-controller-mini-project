`timescale 1ns / 1ps

module DMAC (
input HLDA,DREQ,BG,RST,CLK,RDY,REGW,
input [1:0]REGSEL,
input [7:0]Data_in,
input [15:0]Setup,
output reg HLD,DACK,MEMW,MEMR,IOR,IOW,EOP,
output reg [15:0]Addrbus,
output reg [7:0]Data_out);

// internal registers
reg [15:0] D_addr,S_addr,Counter;
reg [7:0] ctrl_reg,data_buff;


//state values
reg [2:0]state,nxt_state;
parameter IDLE=3'b000, HNDSHAKE=3'b001, READ=3'b010, STORE=3'b011, WRITE=3'b100, WRITE_data=3'b101, UPDATE=3'b110, FLYBY=3'b111;

always@(posedge CLK) 
begin
    if(RST) begin
        data_buff <= 8'h00;
        ctrl_reg <= 8'h00;
        D_addr <= 16'h0000;
        S_addr <= 16'h0000;
        Counter <= 16'h0000;
        Addrbus <= 16'h0000;
        Data_out <= 8'h00;
        nxt_state <= IDLE;
        state <= IDLE;
        IOR <= 0;
        IOW <= 0;
        MEMW <= 0;
        MEMR <= 0;
        HLD <= 0;
        DACK <=0;
        EOP <= 0;
    end
end

always@(nxt_state) state <= nxt_state;

always@(posedge CLK)
begin
    
    case(state) 
            IDLE : begin
                if(DREQ==1) begin
                    HLD <= 1;
                    nxt_state <= HNDSHAKE;
                end
                else 
                    nxt_state <= IDLE;
            end
            HNDSHAKE : begin
                if(REGW) begin
                    case(REGSEL)
                        2'b00 : ctrl_reg <= Setup[7:0];
                        2'b01 : Counter <= Setup;
                        2'b10 : S_addr <= Setup;
                        2'b11 : D_addr <= Setup;
                    endcase
                end
                else if(BG & ctrl_reg[0]) begin
                    HLD <= 0;
                    DACK <= 1;
                    nxt_state <= RDY ? READ : HNDSHAKE ;
                end
                else if (HLDA & (!ctrl_reg[0])) begin
                    DACK <= 1;
                    nxt_state <= RDY ? READ : HNDSHAKE ;
                end
                else begin
                    IOR <= 0;
                    MEMR <= 0;
                    nxt_state <= HNDSHAKE;
                end
            end
            READ : begin
                if ((ctrl_reg[0])&&(!BG)) begin
                    nxt_state <= HNDSHAKE;
                    DACK <= 0;
                    IOR <= 0;
                    MEMR <= 0;
                end
                else begin
                    case(ctrl_reg[5:3])
                        3'b100 : begin
                            Addrbus <= S_addr;
                            MEMR <=1;
                            nxt_state <= ctrl_reg[6] ? FLYBY : STORE;
                        end
                        3'b010 : begin
                            Addrbus <= S_addr;
                            MEMR <= 1;
                            nxt_state <= ctrl_reg[6] ? FLYBY : STORE;
                        end
                        3'b001 : begin
                            IOR <= 1;
                            nxt_state <= ctrl_reg[6] ? FLYBY : STORE;
                        end
                    endcase
                end
            end
            STORE : begin
                if ((ctrl_reg[0])&&(!BG)) begin
                    nxt_state <= HNDSHAKE;
                    DACK <= 0;
                    IOR <= 0;
                    MEMR <= 0;
                end
                else begin
                    data_buff <= Data_in;
                    MEMR <= 0;
                    IOR <= 0;
                    nxt_state <= WRITE;
                end
            end
            WRITE : begin
                if ((ctrl_reg[0])&(!BG)) begin
                    nxt_state <= HNDSHAKE;
                    DACK <= 0;
                    IOW <= 0;
                    MEMW <= 0;
                end
                else begin
                    case(ctrl_reg[5:3])
                        3'b100 : begin
                            Addrbus <= D_addr;
                            Data_out <= data_buff;
                            nxt_state <= WRITE_data;
                        end
                        3'b010 : begin
                            Data_out <= data_buff;
                            nxt_state <= WRITE_data;
                        end
                        3'b001 : begin
                            Addrbus <= D_addr;
                            Data_out <= data_buff;
                            nxt_state <= WRITE_data;
                        end
                    endcase
                end
            end
            WRITE_data : begin
                if ((ctrl_reg[0])&(!BG)) begin
                    nxt_state <= HNDSHAKE;
                    DACK <= 0;
                    IOW <= 0;
                    MEMW <= 0;
                end
                else begin
                    case(ctrl_reg[5:3])
                        3'b100 : begin
                            MEMW <=1;
                            nxt_state <= UPDATE;
                        end
                        3'b010 : begin
                            IOW <= 1;
                            nxt_state <= UPDATE;
                        end
                        3'b001 : begin
                            MEMW <= 1;
                            nxt_state <= UPDATE;
                        end
                    endcase
                end
            end
            FLYBY : begin
                IOR <= 0;
                MEMR <= 0;
                if ((ctrl_reg[0])&&(!BG)) begin
                    nxt_state <= HNDSHAKE;
                    DACK <= 0;
                end
                else begin
                    case(ctrl_reg[5:3]) 
                        3'b100 : begin
                            Addrbus <= D_addr;
                            MEMW <= 1;
                            nxt_state <= UPDATE;
                        end
                        3'b010 : begin
                            IOW <= 1;
                            nxt_state <= UPDATE;
                        end
                        3'b001 : begin
                            Addrbus <= D_addr;
                            MEMW <= 1;
                            nxt_state <= UPDATE;
                        end
                    endcase
                end
            end
            UPDATE : begin
                MEMW <=0;
                IOW <= 0;
                if(Counter==0) begin
                    EOP <=1;
                    HLD <= 0;
                    DACK <= 0;
                    nxt_state <= IDLE;
                end
                else if (DREQ==0) begin
                    HLD <= 0;
                    DACK <= 0;
                    nxt_state <= IDLE;
                end
                else begin
                    Counter <= Counter-1;
                    case(ctrl_reg[5:3])
                        3'b100 : begin
                            D_addr <= ctrl_reg[7] ? (D_addr+1) : (D_addr-1);
                            S_addr <= ctrl_reg[7] ? (S_addr+1) : (S_addr-1);
                        end
                        3'b010 : begin
                            S_addr <= ctrl_reg[7] ? (S_addr+1) : (S_addr-1);
                        end
                        3'b001 : begin
                            D_addr <= ctrl_reg[7] ? (D_addr+1) : (D_addr-1);
                        end
                    endcase
                    case(ctrl_reg[2:0])
                        3'b100 : nxt_state <= RDY ? READ : HNDSHAKE;
                        3'b010 : begin
                            DACK <= 0;
                            HLD <= 0;
                            nxt_state <= IDLE;
                        end
                        3'b001 : begin
                            DACK <= 0;
                            nxt_state <= HNDSHAKE;
                        end
                    endcase
                end
            end     
        endcase
end
endmodule