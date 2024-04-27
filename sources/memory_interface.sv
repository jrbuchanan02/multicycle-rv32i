`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/18/2023 01:16:07 PM
// Design Name: 
// Module Name: memory_interface
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module memory_interface(clock, reset, haddr, hburst, hmastlock, hprot, hsize, htrans, 
                        hwdata, hwrite, hrdata, hreadyout, hresp, cpu_addr, hsel,
                        rdata, wdata, cpu_write, operation_complete, mem_mode,
                        mem_transfer, mem_function);
    parameter XLEN = 32;
    parameter sync_reset = "FALSE";
    
    
    parameter [0:0] mode_word = 0;
    parameter [0:0] mode_func = 1;
    
    input             clock;
    input             reset;
    output [XLEN-1:0] haddr;
    output [2:0]      hburst;
    output            hmastlock;
    output            hsel;
    output [3:0]      hprot;
    output [2:0]      hsize;
    output [1:0]      htrans;
    output [XLEN-1:0] hwdata;
    output            hwrite;
    input  [XLEN-1:0] hrdata;
    input             hreadyout;
    input             hresp; // ignored.
    input  [XLEN-1:0] cpu_addr;
    output [XLEN-1:0] rdata;
    input  [XLEN-1:0] wdata;
    input             cpu_write;
    output            operation_complete;
    input             mem_mode;
    input             mem_transfer;
    input       [2:0] mem_function;
    
    
    typedef enum logic [1:0] {
        state_idle,
        state_addr,
        state_data,
        state_read
    } mi_state;
//    localparam [1:0] state_idle = 3'b00;
//    localparam [1:0] state_addr = 3'b01;
//    localparam [1:0] state_data = 3'b10;
//    localparam [1:0] state_read = 3'b11;
    
    mi_state pstate;
    mi_state nstate;
    
    wire [XLEN-1:0] addr_d, addr_q;
    wire [XLEN-1:0] wdat_d, wdat_q;
    wire [XLEN-1:0] rdat_d, rdat_q;
    wire [2:0] eff_fn_d, eff_fn_q;
    wire write_d, write_q;
    
    wire ld_addr, ld_wdat, ld_rdat, ld_eff_fn, ld_write;
    
    assign addr_d = cpu_addr;
    assign haddr  = addr_q;
    
    assign wdat_d = wdata;
    assign hwdata = wdat_q;
    
    assign rdat_d = eff_fn_q == 3'b000 ? { {XLEN-8{hrdata[7 ]}}, hrdata[ 7:0]} :
                    eff_fn_q == 3'b001 ? { {XLEN-16{hrdata[15]}}, hrdata[15:0]} :
                    eff_fn_q == 3'b010 ? hrdata :
                    eff_fn_q == 3'b100 ? { {XLEN-8{ 1'b0 } }, hrdata[ 7:0]} :
                    eff_fn_q == 3'b101 ? { {XLEN-16{ 1'b0 } }, hrdata[15:0]} : {XLEN{1'bx}}; 
    assign rdata  = rdat_q;
    
    assign eff_fn_d = mem_mode == mode_word ? 3'b010 : mem_function;
    assign hsize    = eff_fn_q[1:0];
    
    assign write_d = cpu_write;
    assign hwrite  = write_q;
    
    // state based logic
    assign nstate = pstate == state_idle ? mem_transfer ? state_addr : state_idle :
                    pstate == state_addr ? state_data :
                    pstate == state_data ? hreadyout ? state_read : state_data :
                    pstate == state_read ? state_idle : state_idle;
                    
    assign htrans = pstate == state_idle ? 2'b00 :
                    pstate == state_addr ? 2'b10 :
                    pstate == state_data ? 2'b00 :
                    pstate == state_read ? 2'b00 : 2'bxx;
    assign operation_complete = pstate == state_idle ? 1'b1 :
                                pstate == state_addr ? 1'b0 :
                                pstate == state_data ? 1'b0 :
                                pstate == state_read ? 1'b0 : 1'bx;
    assign ld_addr = pstate == state_idle ? 1'b1 :
                     pstate == state_addr ? 1'b0 :
                     pstate == state_data ? 1'b0 :
                     pstate == state_read ? 1'b0 : 1'bx;
    assign ld_wdat = pstate == state_idle ? 1'b1 :
                     pstate == state_addr ? 1'b0 :
                     pstate == state_data ? 1'b0 :
                     pstate == state_read ? 1'b0 : 1'bx;
    assign ld_rdat = pstate == state_idle ? 1'b0 :
                     pstate == state_addr ? 1'b0 :
                     pstate == state_data ? 1'b1 :
                     pstate == state_read ? 1'b1 : 1'bx;
    assign ld_eff_fn = pstate == state_idle ? 1'b1 :
                       pstate == state_addr ? 1'b0 :
                       pstate == state_data ? 1'b0 :
                       pstate == state_read ? 1'b0 : 1'bx;
    assign ld_write  = pstate == state_idle ? 1'b1 :
                       pstate == state_addr ? 1'b0 :
                       pstate == state_data ? 1'b0 :
                       pstate == state_read ? 1'b0 : 1'bx;
    assign hsel =    pstate == state_idle ? 1'b0 :
                     pstate == state_addr ? 1'b1 :
                     pstate == state_data ? 1'b1 :
                     pstate == state_read ? 1'b1 : 1'bx;
    
    assign hprot = 4'b0011; // not used, ARM recommends this value when unused.
    assign hmastlock = 0;   // no ability to lock the bus... for now at least
    assign hburst = 3'b000; // single transfer burst.
    
    register addr(.clock(clock),
                  .reset(reset),
                  .ld(ld_addr),
                  .d(addr_d),
                  .q(addr_q));
    register wdat(.clock(clock),
                  .reset(reset),
                  .ld(ld_wdat),
                  .d(wdat_d),
                  .q(wdat_q));
    register rdat(.clock(clock),
                  .reset(reset),
                  .ld(ld_rdat),
                  .d(rdat_d),
                  .q(rdat_q));
    register eff_fn(.clock(clock),
                    .reset(reset),
                    .ld(ld_eff_fn),
                    .d(eff_fn_d),
                    .q(eff_fn_q));
    register write(.clock(clock),
                   .reset(reset),
                   .ld(ld_write),
                   .d(write_d),
                   .q(write_q));
    
    defparam addr.XLEN   = XLEN;
    defparam wdat.XLEN   = XLEN;
    defparam rdat.XLEN   = XLEN;
    defparam eff_fn.XLEN = 3;
    defparam write.XLEN  = 1;
    
    defparam addr.sync_reset = sync_reset;
    defparam wdat.sync_reset = sync_reset;
    defparam rdat.sync_reset = sync_reset;
    defparam eff_fn.sync_reset = sync_reset;
    defparam write.sync_reset = sync_reset;
    
    generate
    if ( sync_reset == "TRUE" ) begin
        always @(posedge clock) begin
            if ( reset ) pstate <= state_idle;
            else         pstate <= nstate;
        end
    end else begin
        always @(posedge clock or posedge reset) begin
            if ( reset ) pstate <= state_idle;
            else         pstate <= nstate;
        end
    end
    endgenerate
endmodule
