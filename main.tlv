\m4_TLV_version 1d: tl-x.org
\SV
   // This code can be found in: https://github.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/risc-v_shell.tlv
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/LF-Building-a-RISC-V-CPU-Core/main/lib/risc-v_shell_lib.tlv'])



   //---------------------------------------------------------------------------------
   // /====================\
   // | Sum 1 to 9 Program |
   // \====================/
   //
   // Program to test RV32I
   // Add 1,2,3,...,9 (in that order).
   //
   // Regs:
   //  x12 (a2): 10
   //  x13 (a3): 1..10
   //  x14 (a4): Sum
   // 
   /*
   //m4_asm(ADDI, x14, x0, 0)             // Initialize sum register a4 with 0
   //m4_asm(ADDI, x12, x0, 1010)          // Store count of 10 in register a2.
   //m4_asm(ADDI, x13, x0, 1)             // Initialize loop count register a3 with 0
   // Loop:
   //m4_asm(ADD, x14, x13, x14)           // Incremental summation
   //m4_asm(ADDI, x13, x13, 1)            // Increment loop count by 1
   //m4_asm(BLT, x13, x12, 1111111111000) // If a3 is less than a2, branch to label named <loop>
   // Test result value in x14, and set x31 to reflect pass/fail.
   //m4_asm(ADDI, x30, x14, 111111010100) // Subtract expected value of 44 to set x30 to 1 if and only iff the result is 45 (1 + 2 + ... + 9).
   //m4_asm(BGE, x0, x0, 0) // Done. Jump to itself (infinite loop). (Up to 20-bit signed immediate plus implicit 0 bit (unlike JALR) provides byte address; last immediate bit should also be 0)
   //m4_asm_end()
   
   */
   //---------------------------------------------------------------------------------
	m4_test_prog()
   m4_define(['M4_MAX_CYC'], 150)

\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   
   $reset = *reset;
   //counter
   //$next_pc[31:0] = $taken_br ? $br_tgt_pc : $pc[31:0] + 30'b1;
   //$pc[31:0] = $reset ? 31'b0 : >>1$next_pc;
   
   $pc[31:0] = $reset ? 32'd0 : >>1$next_pc[31:0];
   
   $next_pc[31:0] =
     $reset ? 32'd0 :
     $is_jal ? $br_tgt_pc[31:0]: 
     $is_jalr ? $jalr_tgt_pc[31:0]: 
     $taken_br ? $br_tgt_pc[31:0] :  
                $pc[31:0] + 32'd4;
     
   //makes some rom.. who knows how but ig its a macro in verilog
   `READONLY_MEM($pc, $$instr[31:0])
   
   //checks what type of instruction it is 
   $is_r_instr = $instr[6:2] ==? 5'b011x0 || $instr[6:2] == 5'b01011 || $instr[6:2] == 5'b10100;
   $is_i_instr = $instr[6:2] ==? 5'b0000x || $instr[6:2] == 5'b001x0 || $instr[6:2] == 5'b11001;
   $is_s_instr = $instr[6:2] ==? 5'b0100x;
   $is_b_instr = $instr[6:2] == 5'b11000;
   $is_u_instr = $instr[6:2] ==? 5'b0x101;
   $is_j_instr = $instr[6:2] ==? 5'b11011;

   //accesses various parts of the instruction message sent by the instruction memory (IMEM)
   $rd[4:0] = $instr[11:7];
   $funct3[2:0] = $instr[14:12];
   $rs1[4:0] = $instr[19:15];
   $rs2[4:0] = $instr[24:20];
   
   //checks if various parts of the instruction output are valid
   $rd_valid = ! $is_s_instr && ! $is_b_instr;
   $funct3_valid = ! $is_u_instr && ! $is_j_instr;
   $rs1_valid = ! $is_u_instr && ! $is_j_instr;
   $rs2_valid = ! $is_u_instr && ! $is_j_instr && ! $is_i_instr;
   $imm_valid = ! $is_r_instr;
   
   //get immediate-- basically the data to be operated on
   $imm[31:0] = 
      $is_i_instr ? { {21{$instr[31]}}, $instr[30:20]} : 
      $is_s_instr ? { {21{$instr[31]}}, $instr[30:25], $instr[11:7]} : 
      $is_b_instr ? { {20{$instr[31]}}, $instr[7], $instr[30:25], $instr[11:8], 1'b0} : 
      $is_u_instr ? { $instr[31:12], 12'b0 } : 
      $is_j_instr ? { {12{$instr[31]}}, $instr[19:12], $instr[20], $instr[30:21], 1'b0} : 
      32'b0;
   
   //decodes instruction selection message into a single binary value so that you only have to check one thing
   $decode_bits[10:0] = {$instr[30], $funct3[2:0], $instr[6:0]};
   //`BOGUS_USE($rd $rd_valid $rs1 $rs1_valid ...)
   //uses decode_bits to detect what type of instruction is being sent to the cpu
   $is_lui = $decode_bits ==? 11'bx_xxx_0110111;
   $is_auipc = $decode_bits ==? 11'bx_xxx_0010111;
   $is_jal = $decode_bits ==? 11'bx_xxx_1101111;

   $is_jalr = $decode_bits ==? 11'bx_000_1100111;
   $is_beq = $decode_bits ==? 11'bx_000_1100011;
   $is_bne = $decode_bits ==? 11'bx_001_1100011;
   $is_blt = $decode_bits ==? 11'bx_100_1100011;
   $is_bge = $decode_bits ==? 11'bx_101_1100011;
   $is_bltu = $decode_bits ==? 11'bx_110_1100011;
   $is_bgeu = $decode_bits ==? 11'bx_111_1100011;
      
   $is_lb = $decode_bits ==? 11'bx_000_0000011;
   $is_lh = $decode_bits ==? 11'bx_001_0000011;
   $is_lw = $decode_bits ==? 11'bx_010_0000011;
   $is_lbu = $decode_bits ==? 11'bx_100_0000011;
   $is_lhu = $decode_bits ==? 11'bx_101_0000011;
   
   $is_sb = $decode_bits ==? 11'bx_000_0100011;
   $is_sh = $decode_bits ==? 11'bx_001_0100011;
   $is_sw = $decode_bits ==? 11'bx_010_0100011;

   
   $is_addi = $decode_bits ==? 11'bx_000_0010011;//add_immediate, adds immediate value to the a specified register
   $is_slti = $decode_bits ==? 11'bx_010_0010011;
   $is_sltiu = $decode_bits ==? 11'bx_011_0010011;
   $is_xori = $decode_bits ==? 11'bx_100_0010011;
   $is_ori = $decode_bits ==? 11'bx_110_0010011;
   $is_andi = $decode_bits ==? 11'bx_111_0010011;

   $is_slli = $decode_bits ==? 11'b0_001_0010011;
   $is_srli = $decode_bits ==? 11'b0_101_0010011;
   $is_srai = $decode_bits ==? 11'b1_101_0010011;
   
   $is_add = $decode_bits ==? 11'b0_000_0110011;//add, adds two register values and puts them somewhere
   $is_sub = $decode_bits ==? 11'b1_000_0110011;
   $is_sll = $decode_bits ==? 11'b0_001_0110011;
   $is_slt = $decode_bits ==? 11'b0_010_0110011;
   $is_sltu = $decode_bits ==? 11'b0_011_0110011;
   $is_xor = $decode_bits ==? 11'b0_100_0110011;
   $is_srl = $decode_bits ==? 11'b0_101_0110011;
   $is_sra = $decode_bits ==? 11'b1_101_0110011;
   $is_or = $decode_bits ==? 11'b0_110_0110011;
   $is_and = $decode_bits ==? 11'b0_111_0110011;
   
   $is_load = $opcode[6:0] ==? 7'b0000011;
   
   //----Arithmetic logic unit----
   $sltu_rslt[31:0] = {31'b0, $src1_value < $src2_value};//sets a value if src1 < src2
   $sltiu_rslt[31:0] = {31'b0, $src1_value < $imm};
   
   $sext_src1[63:0] = { {32{$src1_value[31]}}, $src1_value };//sign extend
   $sra_rslt[63:0] = $sext_src1 >> $src2_value[4:0];
   $srai_rslt[63:0] = $sext_src1 >> $imm[4:0];

   
   $result[31:0] = 
      $is_andi ? $src1_value & $imm : //andI = AND individual, and so on
      $is_ori ? $src1_value | $imm :
      $is_xori ? $src1_value ^ $imm : 
      $is_addi ? $src1_value + $imm : 
      $is_slli ? $src1_value << $imm[5:0] : 
      $is_srli ? $src1_value >> $imm[5:0] : 
      $is_and ? $src1_value & $src2_value : 
      $is_or ? $src1_value | $src2_value : 
      $is_xor ? $src1_value ^ $src2_value : 
      $is_add ? $src1_value + $src2_value : 
      $is_sub ? $src1_value - $src2_value :
      $is_sll ? $src1_value << $src2_value[4:0] : 
      $is_srl ? $src1_value >> $src2_value[4:0] : 
      $is_sltu ? $sltu_rslt : 
      $is_sltiu ? $sltiu_rslt : 
      $is_lui ? {$imm[31:12], 12'b0} :
      $is_auipc ? $pc + $imm : 
      $is_jal ? $pc + 32'd4 :
      $is_jalr ? $pc + 32'd4 :
      $is_slt ? (($src1_value[31] == $src2_value[31]) ? $sltu_rslt : {31'b0, $src1_value[31]}) : 
      $is_slti ? (($src1_value[31] == $imm[31]) ? $sltiu_rslt : {31'b0, $src1_value[31]}) : 
      $is_sra ? $sra_rslt[31:0] : 
      $is_srai ? $srai_rslt[31:0] :
      $is_load ? $rs1 + $imm :
      $is_s_instr ? $rs1 + $imm :
      32'b0;
      

   //tells you if you're allowed to take a branch
   //branching is when (based on a condition) the instruction jumps to another place/time in the cpu
   $taken_br = 
      $is_beq ? $src1_value == $src2_value : 
      $is_bne ? $src1_value != $src2_value : 
      $is_blt ? ($src1_value < $src2_value) ^ ($src1_value[31] != $src2_value[31]) :
      $is_bge ? ($src1_value >= $src2_value) ^ ($src1_value[31] != $src2_value[31]) :
      $is_bltu ? $src1_value < $src2_value : 
      $is_bgeu ? $src1_value >= $src2_value : 
      1'b0;
   
   $br_tgt_pc[31:0] = $imm[31:0] + $pc[31:0];//branch register target program clock time
   $jalr_tgt_pc[31:0] = $src1_value + $imm;//Jump And Link(JAL), for when you need to jump and know where you came from
   
   //----MEMORY----
   $write_result_or_mem = $is_load ? $ld_data : $result;
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = 1'b0;
   *failed = *cyc_cnt > M4_MAX_CYC;
   
   //$rd_is_zero = $rd == 4'b0000;
   //$wr_en = $rd_is_zero ? 1'b0 : 1'b1;
   
   
   m4+rf(32, 32, $reset, $rd_valid, $rd, $write_result_or_mem, $rs1_valid, $rs1,  $src1_value, $rs2_valid, $rs2,  $src2_value)
   
      
   m4+dmem(32, 32, $reset, $result[4:0], $is_s_instr, $src2_value[31:0], $is_load, $ld_data)
   m4+cpu_viz()
\SV
   endmodule
