`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/21/2023 10:11:51 AM
// Design Name: 
// Module Name: main_controller
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

module main_controller(clock, reset, opcode, pc_write, mem_write, ir_write, 
                       write_sel, reg_write, lhs_sel, pc_sel,
                       rhs_sel, alu_mode, imm_fmt, operation_complete, mem_mode, addr_sel, transfer,
                       ld_branch);
    input clock;
    input reset;
    input [6:0] opcode;
    output pc_write;
    output mem_write;
    output ir_write;
    output [1:0] write_sel;
    output reg_write;
    output [1:0] lhs_sel;
    output [1:0] pc_sel;
    output rhs_sel;
    output [1:0] alu_mode;
    output [2:0] imm_fmt;
    input operation_complete;
    output mem_mode;
    output transfer;
    output [1:0] addr_sel;
    output ld_branch;
    
    parameter [2:0] i_type = 0;
    parameter [2:0] s_type = 1;
    parameter [2:0] b_type = 2;
    parameter [2:0] u_type = 3;
    parameter [2:0] j_type = 4;
    
    parameter [1:0] write_ret = 2;
    parameter [1:0] write_res = 0;
    parameter [1:0] write_mem = 1;
    
    parameter [1:0] lhs_is_rs = 0;
    parameter [1:0] lhs_is_pc = 1;
    parameter [1:0] lhs_is_00 = 2;
    
    parameter [0:0] rhs_is_rs = 0;
    parameter [0:0] rhs_is_im = 1;
    
    parameter [1:0] alu_mode_add = 0;
    parameter [1:0] alu_mode_cmp = 1;
    parameter [1:0] alu_mode_fun = 2;
    parameter [1:0] alu_mode_fn3 = 3; // like fun but treat func7 as if all zeros unless if encountering function for SRAI
    
    parameter [0:0] mem_mode_word = 0;
    parameter [0:0] mem_mode_func = 1;
    
    parameter [1:0] addr_sel_curr = 2'b00;
    parameter [1:0] addr_sel_next = 2'b01;
    parameter [1:0] addr_sel_data = 2'b10;
    
    parameter [1:0] pc_sel_next = 2'b00;
    parameter [1:0] pc_sel_jump = 2'b01;
    parameter [1:0] pc_sel_cond = 2'b10;
    
    parameter sync_reset = "FALSE";
    
    parameter [6:0] opcode_load  = 7'b0000011;
    parameter [6:0] opcode_store = 7'b0100011;
    parameter [6:0] opcode_branch= 7'b1100011; 
    parameter [6:0] opcode_jal   = 7'b1101111;
    parameter [6:0] opcode_op_imm= 7'b0010011;
    parameter [6:0] opcode_op    = 7'b0110011;
    parameter [6:0] opcode_auipc = 7'b0010111;
    parameter [6:0] opcode_lui   = 7'b0110111;
    parameter [6:0] opcode_jalr  = 7'b1100111;
    parameter [6:0] opcode_miscmm= 7'b0001111;
    parameter [6:0] opcode_system= 7'b1110011;
    
    typedef enum logic [3:0] {
        state_fetch,
        state_fetwt,
        state_decod,
        state_check,
        state_lword,
        state_sword,
        state_dojal,
        state_jmplr,
        state_luiop,
        state_auipc,
        state_op_im,
        state_do_op,
        state_swait,
        state_lwait
    } cpu_state; 
    
//    localparam [3:0] state_fetch = 4'b0000;
//    localparam [3:0] state_fetwt = 4'b0001;
//    localparam [3:0] state_decod = 4'b0010;
//    localparam [3:0] state_check = 4'b0011;
//    localparam [3:0] state_lword = 4'b0100;
//    localparam [3:0] state_sword = 4'b0101;
//    localparam [3:0] state_dojal = 4'b0110;
//    localparam [3:0] state_jmplr = 4'b0111;
//    localparam [3:0] state_luiop = 4'b1000;
//    localparam [3:0] state_auipc = 4'b1001;
//    localparam [3:0] state_op_im = 4'b1010;
//    localparam [3:0] state_do_op = 4'b1011;
//    localparam [3:0] state_stall = 4'b1100;
    
    cpu_state pstate;
    cpu_state nstate;
    
    logic [1:0] addr_sel;
    logic [1:0] alu_mode;
    logic [2:0] imm_fmt;
    logic ir_write;
    logic [1:0] lhs_sel;
    logic mem_mode;
    logic mem_write;
    logic [1:0] pc_sel;
    logic pc_write;
    logic reg_write;
    logic rhs_sel;
    logic transfer;
    logic [1:0] write_sel;
    logic ld_branch;
    
    always @(posedge clock) begin
        if ( reset ) pstate <= state_fetch;
        else         pstate <= nstate;
    end
    
    always_comb begin
        (* full_case *)
        case ( pstate ) 
        state_fetch:
        begin
            nstate = state_fetwt;
            
            addr_sel = addr_sel_curr;   // select PC as the address
            alu_mode = 'hx; // no particular ALU mode needed.
            imm_fmt  = 'hx; // no particular imm format needed.
            ir_write = 0;   // not writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = 'hx; // no particular lhs
            mem_mode = mem_mode_word; // instruction fetch
            mem_write= 0; // not writing
            pc_sel   = 'hx; // no particular PC 
            pc_write = 0; // not writing PC
            reg_write= 0; // not writing rd
            rhs_sel  = 'hx; // no particular rhs
            transfer = 1; // want a transfer
            write_sel= 'hx; // no particularly important selection
        end
        state_fetwt:
        begin
            nstate = operation_complete ? state_decod : state_fetwt;
            
            addr_sel = 'hx; // no particular address selection needed.
            alu_mode = 'hx; // no particular ALU mode needed.
            imm_fmt  = 'hx; // no particular imm format needed.
            ir_write = 1;   // writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = 'hx; // no particular lhs
            mem_mode = 'hx; // no particular memory mode.
            mem_write= 'hx; // not starting a transaction.
            pc_sel   = 'hx; // no particular PC
            pc_write = 0; // not writing PC
            reg_write= 0; // not writing rd
            rhs_sel  = 'hx; // no particular rhs
            transfer = 0; // not starting a transfer
            write_sel= 'hx; // no particularly important selection
        end
        state_decod:
        begin
            if ( opcode[1:0] != 2'b11 ) nstate = state_decod;
            else casez ( opcode )
            opcode_load:    nstate = state_lword;
            opcode_store:   nstate = state_sword;
            opcode_branch:  nstate = state_check;
            opcode_jal:     nstate = state_dojal;
            opcode_op:      nstate = state_do_op;
            opcode_op_imm:  nstate = state_op_im;
            opcode_auipc:   nstate = state_auipc;
            opcode_lui:     nstate = state_luiop;
            opcode_jalr:    nstate = state_jmplr;
            opcode_miscmm:  nstate = state_fetch;
            opcode_system:  nstate = state_fetch;
            default:        nstate = state_decod;
            endcase
            
            addr_sel = 'hx;          // no particular address selection needed
            alu_mode = alu_mode_add; // calculate branch offset.
            imm_fmt  = b_type; // branch offset.
            ir_write = 0;   // not writing IR. 
            ld_branch = 1; // calculating branch offset.
            lhs_sel  = lhs_is_pc; // branch offset.
            mem_mode = 'hx; // no particular memory mode.
            mem_write= 'hx; // not starting a transaction.
            pc_sel   = pc_sel_next; // in case of miscmm or system
            pc_write = opcode == opcode_miscmm || opcode == opcode_system ? 1 : 0; // update PC iff MISC-MEM or SYSTEM
            reg_write= 0; // not writing rd
            rhs_sel  = rhs_is_im; // branch offset
            transfer = 0; // not starting a transfer
            write_sel= 'hx; // no particularly important selection
        end
        state_check:
        begin
            nstate = state_fetch;
            
            addr_sel = 'hx; // no particular address selection
            alu_mode = alu_mode_cmp; // branch.
            imm_fmt  = 'hx;          // no particular imm format needed
            ir_write = 0;   // not writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = lhs_is_rs; // left hand side
            mem_mode = 'hx; // not performing a memory operation
            mem_write= 'hx; // not performing a memory operation
            pc_sel   = pc_sel_cond; // branch target
            pc_write = 1; // writing PC
            reg_write= 0; // not writing rd
            rhs_sel  = rhs_is_rs; // right hand side
            transfer = 0; // don't want a transfer
            write_sel= 'hx; // no particularly important selection
        end
        state_lword:
        begin
            nstate = state_lwait;
            
            addr_sel = addr_sel_data;// for reading the address. 
            alu_mode = alu_mode_add; // effective addr
            imm_fmt  = i_type; // addr offset.
            ir_write = 0;   // not writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = lhs_is_rs; // left hand side
            mem_mode = mem_mode_func; // memory transaction
            mem_write= 0; // not writing
            pc_sel   = pc_sel_next; // no particular PC
            pc_write = 1; // writing PC
            reg_write= 0; // not writing rd
            rhs_sel  = rhs_is_im; // right hand side
            transfer = 1; // want a transfer
            write_sel= 'hx; // no particularly important selection
        end
        state_sword:
        begin
            nstate = state_swait;
            
            addr_sel = addr_sel_data;// for reading the address.
            alu_mode = alu_mode_add; // effective addr
            imm_fmt  = s_type; // addr offset
            ir_write = 0;   // not writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = lhs_is_rs; // left hand side
            mem_mode = mem_mode_func; // memory transaction
            mem_write= 1; // writing.
            pc_sel   = pc_sel_next; // no particular PC
            pc_write = 1; // writing PC
            reg_write= 0; // not writing rd
            rhs_sel  = rhs_is_im; // right hand side
            transfer = 1; // want a transfer
            write_sel= 'hx; // no particularly important selection
        end
        state_dojal:
        begin
            nstate = state_fetwt;
            
            addr_sel = addr_sel_data; // jump target
            alu_mode = alu_mode_add; // effective addr
            imm_fmt  = j_type; // jump offset
            ir_write = 0;   // not writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = lhs_is_pc; // jump offset.
            mem_mode = mem_mode_word; // instruction fetch
            mem_write= 0; // not writing
            pc_sel   = pc_sel_jump; // jump target
            pc_write = 1; // writing PC
            reg_write= 1; // writing rd
            rhs_sel  = rhs_is_im; // right hand side
            transfer = 1; // want a transfer
            write_sel= write_ret; // return address
        end
        state_jmplr:
        begin
            nstate = state_fetwt;
            
            addr_sel = addr_sel_data; // jump target
            alu_mode = alu_mode_add; // effective addr
            imm_fmt  = i_type; // jump offset
            ir_write = 0;   // not writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = lhs_is_rs; // left hand side
            mem_mode = mem_mode_word; // instruction fetch
            mem_write= 0; // not writing
            pc_sel   = pc_sel_jump; // jump target
            pc_write = 1; // writing PC
            reg_write= 1; // writing rd
            rhs_sel  = rhs_is_im; // right hand side
            transfer = 1; // want a transfer
            write_sel= write_ret; // return address
        end
        state_luiop:
        begin
            nstate = state_fetwt;
            
            addr_sel = addr_sel_next; // next instruction
            alu_mode = alu_mode_add; // that's just how we get the upper imm.
            imm_fmt  = u_type; // upper immediate
            ir_write = 0;   // not writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = lhs_is_00; // left hand side
            mem_mode = mem_mode_word; // instruction fetch
            mem_write= 0; // not writing
            pc_sel   = pc_sel_next; // next PC
            pc_write = 1; // writing PC
            reg_write= 1; // writing rd
            rhs_sel  = rhs_is_im; // right hand side
            transfer = 1; // want a transfer
            write_sel= write_res; // calculation result
        end
        state_auipc:
        begin
            nstate = state_fetwt;
            
            addr_sel = addr_sel_next; // next instruction
            alu_mode = alu_mode_add; // add with PC
            imm_fmt  = u_type; // upper immediate
            ir_write = 0;   // not writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = lhs_is_pc; // that's what the PC means
            mem_mode = mem_mode_word; // instruction fetch
            mem_write= 0; // not writing
            pc_sel   = pc_sel_next; // next PC
            pc_write = 1; // writing PC
            reg_write= 1; // writing rd
            rhs_sel  = rhs_is_im; // right hand side
            transfer = 1; // want a transfer
            write_sel= write_res; // calculation result
        end
        state_op_im:
        begin
            nstate = state_fetwt;
            
            addr_sel = addr_sel_next; // next instruction
            alu_mode = alu_mode_fn3; // only depends on func3
            imm_fmt  = i_type; // immediate
            ir_write = 0;   // not writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = lhs_is_rs; // left hand side
            mem_mode = mem_mode_word; // instruction fetch
            mem_write= 0; // not writing
            pc_sel   = pc_sel_next; // next PC
            pc_write = 1; // writing PC
            reg_write= 1; // writing rd
            rhs_sel  = rhs_is_im; // right hand side
            transfer = 1; // want a transfer
            write_sel= write_res; // calculation result
        end
        state_do_op:
        begin
            nstate = state_fetwt;
            
            addr_sel = addr_sel_next; // next instruction
            alu_mode = alu_mode_fun; // depends on function fields
            imm_fmt  = 'hx; // immediate unused
            ir_write = 0;   // not writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = lhs_is_rs; // left hand side
            mem_mode = mem_mode_word; // instruction fetch
            mem_write= 0; // not writing
            pc_sel   = pc_sel_next; // next PC
            pc_write = 1; // writing PC
            reg_write= 1; // writing rd
            rhs_sel  = rhs_is_rs; // right hand side
            transfer = 1; // want a transfer
            write_sel= write_res; // calculation result
        end
        state_swait:
        begin
            nstate = operation_complete ? state_fetch : state_swait;
            
            addr_sel = 'hx; // no particular address selection needed
            alu_mode = 'hx; // no particular ALU mode.
            imm_fmt  = 'hx; // immediate unused
            ir_write = 0;   // not writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = 'hx; // no particular lhs
            mem_mode = 'hx; // no particular memory mode.
            mem_write= 'hx; // not starting a transaction.
            pc_sel   = 'hx; // no particular PC
            pc_write = 0; // not writing PC
            reg_write= 0; // not writing rd
            rhs_sel  = 'hx; // no particular rhs
            transfer = 0; // not starting a transfer
            write_sel= 'hx; // no particularly important selection
        end
        state_lwait:
        begin
            nstate = operation_complete ? state_fetch : state_lwait;
            
            addr_sel = 'hx; // no particular address selection needed
            alu_mode = 'hx; // no particular ALU mode.
            imm_fmt  = 'hx; // immediate unused
            ir_write = 0;   // not writing IR.
            ld_branch = 0; // not calculating branch offset.
            lhs_sel  = 'hx; // no particular lhs
            mem_mode = 'hx; // no particular memory mode.
            mem_write= 'hx; // not starting a transaction.
            pc_sel   = 'hx; // no particular PC
            pc_write = 0; // not writing PC
            reg_write= 1; // writing rd
            rhs_sel  = 'hx; // no particular rhs
            transfer = 0; // not starting a transfer
            write_sel= write_mem; // value read from memory
        end
        endcase
    end
    
endmodule
