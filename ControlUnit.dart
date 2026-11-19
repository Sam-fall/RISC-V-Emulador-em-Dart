class ControlUnit() {
  
  bool ulaSrcA = false; // false = rs1 | true = PC (para AUIPC)
  bool ulaSrcB = false; // false = rs2 | true = Imediato (seu antigo ulaSrc)
  bool regWrite = false; // Permissão para gravar no rd
  bool memRead = false; // Permissão para ler da RAM
  bool memWrite = false; // Permissão para gravar na RAM
  bool branch = false; // Instrução de salto condicional (Tipo-B)
  bool jump = false; // Salto incondicional (JAL / JALR)
  bool isJalr = false; // Diferencia JAL (PC + imm) de JALR (rs1 + imm)

  void Opcode(int instruction){  
    int opcode = instruction & 0x7F;

    switch (opcode) {
      case 0x37: { // Tipo-U LUI (Load Upper Immediate)
       
        tipoU_LUI();
        break;
      }

      case 0x17: { // Tipo-U AUIPC (Add Upper Immediate to PC)
        
        tipoU_AUIPC();
        break;
      }

      case 0x6F: { // Tipo-J JAL (Jump and Link)
      
        tipoJ();
        break;
      }

      case 0x67: { // Tipo-I JALR (Jump and Link Register)
        int funct3 = (instruction >> 12) & 0x7;
        
        tipoI_JALR(funct3);
        break;
      }

      case 0x03: { // Tipo-I LOADS (LB, LH, LW, LBU, LHU)

        int funct3 = (instruction >> 12) & 0x7;
        
        tipoI_LOADS(funct3);
        break;
      }

      case 0x13: { // TIPO-I ARITMÉTICO/LÓGICO
          int funct3 = (instruction >> 12) & 0x7;
          int funct7 = (instruction >> 25) & 0x7F;
        
        tipoI_ARITHMETIC_LOGIC(funct7, funct3);
        break;
      }

      case 0x0F: { // Tipo-I FENCE (Sincronização)
        int funct3 = (instruction >> 12) & 0x7;

        tipoI_FENCE( funct3);
        break;
      }

      case 0x73: { // Tipo-I ENVIRONMENT / CSR
        int funct3 = (instruction >> 12) & 0x7;
        int funct12 = (instruction >> 20) & 0xFFF;
        
        tipoI_EVERINMENT_CSR(funct12, funct3);
        break;
      }

      case 0x63: { // Tipo-B BRANCHES (BEQ, BNE, BLT, etc.)
        int funct3 = (instruction >> 12) & 0x7;
          
        tipoB(funct3);
        break;
      }

      case 0x23: { // Tipo-S STORES (SB, SH, SW)
        int funct3 = (instruction >> 12) & 0x7; 
        
        tipoS(funct3);
        break;
      }

      case 0x33: { // TIPO-R ARITMÉTICO/LÓGICO (ADD, SUB, etc.)
        int funct3 = (instruction >> 12) & 0x7;
        int funct7 = (instruction >> 25) & 0x7F;
        
        tipoR(funct3, funct7);
        break;
      }

      default:
        throw Exception("Opcode Desconhecido ou Instrução Inválida: ${instruction.toRadixString(16)}");
    }
  }   

  void tipoU_LUI(){
    print("lui");

  }

  void tipoU_AUIPC(){
    print("auipc");

  }

  void tipoJ(){
    print("jal");

  }

  void tipoI_JALR(int funct3) {
    switch (funct3) {
      
      // jalr 
      case 0x00: {
        print("jalr");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I JALR: $funct3");
    }

  }
  
  void tipoI_LOADS(int funct3) {
    switch (funct3) {
      
      // lb 
      case 0x0: {
        print("lb");
        break;
      }
      
      // lh 
      case 0x1: {
        print("lh");
        break;
      }
      
      // lw 
      case 0x2: {
        print("lw");
        break;
      }
      
      // lbu 
      case 0x4: {
        print("lbu");
        break;
      }
      
      // lhu 
      case 0x5: {
        print("lhu");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I Loads: $funct3");
    }

  }

  void tipoI_ARITHMETIC_LOGIC(int funct7,int funct3) {
  switch (funct3) {
    
    //addi
    case 0x0: {
      print("addi");
      break;
    }
    
    //slli
    case 0x1: {
      // No SLLI, a quantidade de shift (shamt) são apenas os 5 bits inferiores do imediato
      //int shamt = imm11_0 & 0x1F;
      print("slli");
      break;
    }
    
    //slti
    case 0x2: { 
      print("slti");
      break;
    }
    
    //sltiu
    case 0x3: {
      print("sltiu");
      break;
    }
    
    //xori
    case 0x4: { 
      print("xori");
      break;
    }
    
    //srli srai
    case 0x5: { 
      
      if (funct7 == 0x00) {     
        print("srli"); 
        break;
      } else if (funct7 == 0x20) { 
        print("srai"); 
        break;
      }
      
      throw Exception("Instrução de shift inválida. Funct7_imm incorreto: 0x${funct7.toRadixString(16)}");
    }
    
    //ori
    case 0x6: {
      print("ori");
      break;
    }
    
    //andi
    case 0x7: {
      print("andi");
      break;
    }
    
    default:
      throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I Aritmético: $funct3");
  }
  
}

  void tipoI_FENCE(int funct3) {
  switch (funct3) {

    //fence    
    case 0x0: {
      print("fence");
      break;
    }
    
    // fence.i
    case 0x1: {
      print("fence.i");
      break;
    }
    
    default:
      throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I Fence: $funct3");
  }
  
}

  void tipoI_EVERINMENT_CSR( int funct12, int funct3) {
    switch (funct3) {
      
      // ecall, ebreak
      case 0x00: {
        if (funct12 == 0x00) {
          print("ecall");
          break;
        } else if (funct12 == 0x01) {
          print("ebreak");
          break;
        }
        
        throw Exception("Instrução de ambiente inválida. funct12 incorreto: 0x${funct12.toRadixString(16)}");
      }
      
      // csrrw
      case 0x01: {
        print("csrrw");
        break;
      }
      
      // csrrs
      case 0x02: {
        print("csrrs");
        break;
      }
      
      // csrrc
      case 0x03: {
        print("csrrc");
        break;
      }
      
      // csrrwi
      case 0x05: {
        print("csrrwi");
        break;
      }
      
      // csrrsi
      case 0x06: {
        print("csrrsi");
        break;
      }
      
      // csrrci
      case 0x07: {
        print("csrrci");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I Environment/CSR: $funct3");
    }

  }

  void tipoB(int funct3) {
    switch (funct3) {
      
      // beq 
      case 0x0: {
        print("beq");
        break;
      }
      
      // bne 
      case 0x1: {
        print("bne");
        break;
      }
      
      // blt
      case 0x4: {
        print("blt");
        break;
      }
      
      // bge 
      case 0x5: {
        print("bge");
        break;
      }
      
      // bltu 
      case 0x6: {
        print("bltu");
        break;
      }
      
      // bgeu 
      case 0x7: {
        print("bgeu");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-B (Branches): $funct3");
    }

  }

  void tipoS(int funct3) {
    switch (funct3) {
      
      // sb 
      case 0x0: {
        print("sb");
        break;
      }
      
      // sh
      case 0x1: {
        print("sh");
        break;
      }
      
      // sw
      case 0x2: {
        print("sw");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-S: $funct3");
    }

  } 

  void tipoR(funct3, int funct7){
    switch (funct3){
      //add sub
      case 0x00: {
        if(funct7 == 0x20){
          //sub
          print("sub");
          break;

        } else if(funct7 == 0x00){
          //add
          print("add");
          break;
        }

        throw Exception("funct7 desconhecido ou instrução inválida para Tipo-R: ${funct7.toRadixString(16)}");
      }

      //sll
      case 0x01: {
        print("sll");
        break;
      }

      //slt
      case 0x02: {
        print("slt");
        break;
      }

      //sltu
      case 0x03: {
        print("sltu");
        break;
      }

      //xor 
      case 0x04: {
        print("xor");
        break;
      }

      //srl sra 
      case 0x05: {
        if(funct7 == 0x20){
          //sra
          print("sra");
          break;
        } else if(funct7 == 0x00){
          //srl
          print("srl");
          break;
        }
        throw Exception("funct7 desconhecido ou instrução inválida para Tipo-R: ${funct7.toRadixString(16)}");
      }

      //or
      case 0x06: {
        print("or");
        break;
      }

      //and
      case 0x07: {
        print("and");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-R: ${funct3.toRadixString(16)}");
    }
  }

}

void main() {

  Map<String, int> testesRV32I = {
    
    // --- Tipo R (Opcode 0x33) ---
    "add"   : 0x00000033,
    "sub"   : 0x40000033,
    "sll"   : 0x00001033,
    "slt"   : 0x00002033,
    "sltu"  : 0x00003033,
    "xor"   : 0x00004033,
    "srl"   : 0x00005033,
    "sra"   : 0x40005033,
    "or"    : 0x00006033,
    "and"   : 0x00007033,

    // --- Tipo I: Aritmético/Lógico (Opcode 0x13) ---
    "addi"  : 0x00000013,
    "slli"  : 0x00001013,
    "slti"  : 0x00002013,
    "sltiu" : 0x00003013,
    "xori"  : 0x00004013,
    "srli"  : 0x00005013,
    "srai"  : 0x40005013,
    "ori"   : 0x00006013,
    "andi"  : 0x00007013,

    // --- Tipo I: Loads (Opcode 0x03) ---
    "lb"    : 0x00000003,
    "lh"    : 0x00001003,
    "lw"    : 0x00002003,
    "lbu"   : 0x00004003,
    "lhu"   : 0x00005003,

    // --- Tipo I: JALR (Opcode 0x67) ---
    "jalr"  : 0x00000067,

    // --- Tipo I: Fence (Opcode 0x0F) ---
    "fence"   : 0x0000000F,
    "fence.i" : 0x0000100F,

    // --- Tipo I: Environment / CSR (Opcode 0x73) ---
    "ecall"   : 0x00000073,
    "ebreak"  : 0x00100073,
    "csrrw"   : 0x00001073,
    "csrrs"   : 0x00002073,
    "csrrc"   : 0x00003073,
    "csrrwi"  : 0x00005073,
    "csrrsi"  : 0x00006073,
    "csrrci"  : 0x00007073,

    // --- Tipo S: Stores (Opcode 0x23) ---
    "sb"    : 0x00000023,
    "sh"    : 0x00001023,
    "sw"    : 0x00002023,

    // --- Tipo B: Branches (Opcode 0x63) ---
    "beq"   : 0x00000063,
    "bne"   : 0x00001063,
    "blt"   : 0x00004063,
    "bge"   : 0x00005063,
    "bltu"  : 0x00006063,
    "bgeu"  : 0x00007063,

    // --- Tipo U (Opcodes 0x17 e 0x37) ---
    "auipc" : 0x00000017,
    "lui"   : 0x00000037,

    // --- Tipo J: JAL (Opcode 0x6F) ---
    "jal"   : 0x0000006F,
  };

  print("========================================");
  print("INICIANDO BATERIA DE TESTES DO DECODER");
  print("========================================");

  var controlUnit = ControlUnit();

  int total = testesRV32I.length;
  int contador = 1;

  testesRV32I.forEach((nomeEsperado, instrucaoHex) {
    print("\n[$contador/$total] Testando: '$nomeEsperado'");
    print("----------------------------------------");
    
    controlUnit.Opcode(instrucaoHex);
    
    contador++;
  });
  
  print("\n========================================");
  print("TESTES CONCLUÍDOS!");
}