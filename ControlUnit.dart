import 'Ula.dart';

class ControlUnit {
  
  //Sinais de entrada mux de escrita para o banco de registradores
  static const int RESULT_ULA = 0;
  static const int RESULT_MEM = 1;
  static const int RESULT_PC4 = 2;
  static const int RESULT_IMM = 3;
  static const int RESULT_RS1 = 4; //Leva rs1 direto para rd (usado no CMOV)

  bool ulaSrcA = false;   // false = rs1 | true = PC (para AUIPC)
  bool ulaSrcB = false;   // false = rs2 | true = Imediato (seu antigo ulaSrc)
  bool regWrite = false;  // Permissão para gravar no rd
  bool memRead = false;   // Permissão para ler da RAM
  bool memWrite = false;  // Permissão para gravar na RAM
  bool branch = false;    // Instrução de salto condicional (Tipo-B)
  bool jump = false;      // Salto incondicional (JAL / JALR)
  bool isJalr = false;    // Diferencia JAL (PC + imm) de JALR (rs1 + imm)
  bool isCmov = false; // Habilita escrita condicional no rd (apenas se rs2 != 0)

  int resultSrc = RESULT_ULA;
  int ulaOp     = Ula.OP_ADD; // Exposto para a ULA avaliar qual operação realizar
  int funct3    = 0;          // Exposto para a CPU avaliar Branch e tamanho de Load/Store

  void _resetarSinais() {
    ulaSrcA   = false;
    ulaSrcB   = false;
    regWrite  = false;
    memRead   = false;
    memWrite  = false;
    branch    = false;
    jump      = false;
    isJalr    = false;
    isCmov    = false;
    resultSrc = RESULT_ULA;
    ulaOp     = Ula.OP_ADD;
    funct3    = 0;
  }

  void Opcode(int instruction){  
    _resetarSinais();
    int opcode = instruction & 0x7F;
    funct3 = (instruction >> 12) & 0x7;

    switch (opcode) {

      case 0x0B: // Instrução escolhida pelo Prof. CMOV
        tipoR_CMOV();
        break;

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

  void tipoR_CMOV() {
    print("Tipo R (Custom) - cmov, copia rs1 para rd somente se rs2 != 0.");
    regWrite  = true;       // Intenção de gravar no rd (filtrada pela condição na CPU)
    isCmov    = true;       // Avisa a CPU para checar se rs2 != 0 antes de gravar
    resultSrc = RESULT_RS1; // MUX de Write-Back seleciona o valor de rs1 direto
  }

 void tipoU_LUI() {
    print("Tipo U - lui, usado para carregar um imediato de 20 bits no registrador de destino (rd).");
    regWrite = true;        // Libera gravação no rd
    resultSrc = RESULT_IMM; // MUX de Write-Back seleciona o imediato puro do ImmGen
  }

  void tipoU_AUIPC() {
    print("Tipo U - auipc, usado para adicionar um imediato de 20 bits ao PC e armazenar o resultado no registrador de destino (rd).");
    ulaSrcA = true;         // Entrada A da ULA recebe o PC (em vez de rs1)
    ulaSrcB = true;         // Entrada B da ULA recebe o imediato
    regWrite = true;        // Libera gravação no rd
    resultSrc = RESULT_ULA; // MUX de Write-Back seleciona o resultado da ULA
    ulaOp = Ula.OP_ADD;     // ULA calcula PC + imm
  }

  void tipoJ() {
    print("Tipo J - jal, usado para saltar para PC + imediato e salvar PC + 4 em rd.");
    jump = true;            // Salto incondicional (novo PC será PC + imm)
    regWrite = true;        // Libera gravação no rd
    resultSrc = RESULT_PC4; // MUX de Write-Back seleciona PC + 4
  }

  void tipoI_JALR(int funct3) {
    switch (funct3) {
      
      // jalr 
      case 0x00: {
        print("Tipo I - jalr, usado para saltar para (rs1 + imediato) & ~1 e salvar PC + 4 em rd.\n O bit menos significativo do endereço de destino é forçado a 0 para garantir alinhamento & ~1.");
        jump = true;            // Salto incondicional
        isJalr = true;          // Avisa a CPU que o novo PC vem da ULA, não de PC + imm
        ulaSrcB = true;         // Entrada B da ULA recebe o imediato (Entrada A já é rs1)
        ulaOp = Ula.OP_ADD;     // ULA calcula rs1 + imm
        regWrite = true;        // Libera gravação no rd
        resultSrc = RESULT_PC4; // MUX de Write-Back seleciona PC + 4
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I JALR: $funct3");
    }
  }
  
  void tipoI_LOADS(int funct3) {
    ulaSrcB = true;         // Entrada B da ULA recebe o imediato (calcula endereço: rs1 + imm)
    ulaOp = Ula.OP_ADD;     // ULA soma base + deslocamento
    memRead = true;         // Libera leitura da Memória RAM
    regWrite = true;        // Libera gravação no rd
    resultSrc = RESULT_MEM; // MUX de Write-Back seleciona o dado vindo da RAM

    switch (funct3) {
      // lb
      case 0x0: {
        print("Tipo I - lb, lê 1 byte da RAM (rs1 + imm) com extensão de sinal e salva em rd.");
        break;
      }

      // lh
      case 0x1: {
        print("Tipo I - lh, lê 2 bytes da RAM (rs1 + imm) com extensão de sinal e salva em rd.");
        break;
      }

      // lw
      case 0x2: {
        print("Tipo I - lw, lê 4 bytes (word) da RAM (rs1 + imm) e salva em rd.");
        break;
      }

      // lbu
      case 0x4: {
        print("Tipo I - lbu, lê 1 byte da RAM (rs1 + imm) sem sinal (zero-extended) e salva em rd.");
        break;
      }

      // lhu
      case 0x5: {
        print("Tipo I - lhu, lê 2 bytes da RAM (rs1 + imm) sem sinal (zero-extended) e salva em rd.");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I Loads: $funct3");
    }
  }

  void tipoI_ARITHMETIC_LOGIC(int funct7, int funct3) {
    ulaSrcB = true;         // Entrada B da ULA recebe o imediato (Entrada A já é rs1)
    regWrite = true;        // Libera gravação no rd
    resultSrc = RESULT_ULA; // MUX de Write-Back seleciona o resultado da ULA

    switch (funct3) {
      // addi
      case 0x0: {
        print("Tipo I - addi, soma rs1 com imediato e salva em rd.");
        ulaOp = Ula.OP_ADD; // ULA calcula rs1 + imm
        break;
      }

      // slli
      case 0x1: {
        print("Tipo I - slli, desloca rs1 à esquerda pelos 5 bits inferiores do imediato e salva em rd.");
        ulaOp = Ula.OP_SLL; // ULA calcula rs1 << (imm & 0x1F)
        break;
      }

      // slti
      case 0x2: {
        print("Tipo I - slti, compara rs1 < imediato (com sinal) e salva 1 ou 0 em rd.");
        ulaOp = Ula.OP_SLT; // ULA compara com sinal
        break;
      }

      // sltiu
      case 0x3: {
        print("Tipo I - sltiu, compara rs1 < imediato (sem sinal) e salva 1 ou 0 em rd.");
        ulaOp = Ula.OP_SLTU; // ULA compara sem sinal
        break;
      }

      // xori
      case 0x4: {
        print("Tipo I - xori, faz XOR bit a bit entre rs1 e imediato e salva em rd.");
        ulaOp = Ula.OP_XOR; // ULA calcula rs1 ^ imm
        break;
      }

      // srli / srai
      case 0x5: {
        if (funct7 == 0x00) {
          print("Tipo I - srli, deslocamento lógico à direita (preenche com 0) e salva em rd.");
          ulaOp = Ula.OP_SRL; // ULA calcula rs1 >>> (imm & 0x1F)
          break;
        } else if (funct7 == 0x20) {
          print("Tipo I - srai, deslocamento aritmético à direita (mantém sinal) e salva em rd.");
          ulaOp = Ula.OP_SRA; // ULA calcula rs1 >> (imm & 0x1F)
          break;
        }

        throw Exception("Instrução de shift inválida. Funct7_imm incorreto: 0x${funct7.toRadixString(16)}");
      }

      // ori
      case 0x6: {
        print("Tipo I - ori, faz OR bit a bit entre rs1 e imediato e salva em rd.");
        ulaOp = Ula.OP_OR; // ULA calcula rs1 | imm
        break;
      }

      // andi
      case 0x7: {
        print("Tipo I - andi, faz AND bit a bit entre rs1 e imediato e salva em rd.");
        ulaOp = Ula.OP_AND; // ULA calcula rs1 & imm
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I Aritmético: $funct3");
    }
  }

  void tipoI_FENCE(int funct3) {
    // Em um emulador single-cycle/single-core, FENCE atua como NOP (nenhum sinal ativado)
    switch (funct3) {
      // fence
      case 0x0: {
        print("Tipo I - fence, sincroniza acessos à memória (atua como NOP em single-core).");
        break;
      }

      // fence.i
      case 0x1: {
        print("Tipo I - fence.i, sincroniza cache de instruções (atua como NOP em single-core).");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I Fence: $funct3");
    }
  }

  void tipoI_EVERINMENT_CSR(int funct12, int funct3) {
    // Sinais permanecem desligados até que um banco de registradores CSR/Syscalls seja implementado
    switch (funct3) {
      // ecall, ebreak
      case 0x00: {
        if (funct12 == 0x000) {
          print("Tipo I - ecall, chamada de sistema ao ambiente (OS/Syscall).");
          break;
        } else if (funct12 == 0x001) {
          print("Tipo I - ebreak, pausa a execução para o depurador (breakpoint).");
          break;
        }

        throw Exception("Instrução de ambiente inválida. funct12 incorreto: 0x${funct12.toRadixString(16)}");
      }

      // csrrw
      case 0x01: {
        print("Tipo I - csrrw, lê CSR para rd e grava rs1 no CSR.");
        break;
      }

      // csrrs
      case 0x02: {
        print("Tipo I - csrrs, lê CSR para rd e ativa bits usando máscara de rs1.");
        break;
      }

      // csrrc
      case 0x03: {
        print("Tipo I - csrrc, lê CSR para rd e limpa bits usando máscara de rs1.");
        break;
      }

      // csrrwi
      case 0x05: {
        print("Tipo I - csrrwi, lê CSR para rd e grava imediato de 5 bits no CSR.");
        break;
      }

      // csrrsi
      case 0x06: {
        print("Tipo I - csrrsi, lê CSR para rd e ativa bits usando imediato de 5 bits.");
        break;
      }

      // csrrci
      case 0x07: {
        print("Tipo I - csrrci, lê CSR para rd e limpa bits usando imediato de 5 bits.");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-I Environment/CSR: $funct3");
    }
  }

  void tipoB(int funct3) {
    branch = true;   // Habilita salto condicional (CPU avalia o resultado da ULA + funct3)
    ulaSrcB = false; // Entrada B da ULA recebe rs2 (compara rs1 com rs2)
    regWrite = false; // Branches não gravam em registradores

    switch (funct3) {
      // beq
      case 0x0: {
        print("Tipo B - beq, salta para PC + imm se rs1 == rs2.");
        ulaOp = Ula.OP_SUB; // ULA calcula rs1 - rs2 (bitflag == true se forem iguais)
        break;
      }

      // bne
      case 0x1: {
        print("Tipo B - bne, salta para PC + imm se rs1 != rs2.");
        ulaOp = Ula.OP_SUB; // ULA calcula rs1 - rs2 (bitflag == false se forem diferentes)
        break;
      }

      // blt
      case 0x4: {
        print("Tipo B - blt, salta para PC + imm se rs1 < rs2 (com sinal).");
        ulaOp = Ula.OP_SLT; // ULA retorna 1 se rs1 < rs2
        break;
      }

      // bge
      case 0x5: {
        print("Tipo B - bge, salta para PC + imm se rs1 >= rs2 (com sinal).");
        ulaOp = Ula.OP_SLT; // ULA retorna 0 se rs1 >= rs2
        break;
      }

      // bltu
      case 0x6: {
        print("Tipo B - bltu, salta para PC + imm se rs1 < rs2 (sem sinal).");
        ulaOp = Ula.OP_SLTU; // ULA retorna 1 se rs1 < rs2 (unsigned)
        break;
      }

      // bgeu
      case 0x7: {
        print("Tipo B - bgeu, salta para PC + imm se rs1 >= rs2 (sem sinal).");
        ulaOp = Ula.OP_SLTU; // ULA retorna 0 se rs1 >= rs2 (unsigned)
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-B (Branches): $funct3");
    }
  }

  void tipoS(int funct3) {
    ulaSrcB = true;     // Entrada B da ULA recebe o imediato (calcula endereço: rs1 + imm)
    ulaOp = Ula.OP_ADD; // ULA soma base + deslocamento
    memWrite = true;    // Libera escrita na Memória RAM (grava o valor de rs2)
    regWrite = false;   // Stores não gravam no Banco de Registradores

    switch (funct3) {
      // sb
      case 0x0: {
        print("Tipo S - sb, grava o byte inferior (8 bits) de rs2 na RAM (rs1 + imm).");
        break;
      }

      // sh
      case 0x1: {
        print("Tipo S - sh, grava a halfword inferior (16 bits) de rs2 na RAM (rs1 + imm).");
        break;
      }

      // sw
      case 0x2: {
        print("Tipo S - sw, grava a word inteira (32 bits) de rs2 na RAM (rs1 + imm).");
        break;
      }

      default:
        throw Exception("Funct3 desconhecido ou instrução invalida para Tipo-S: $funct3");
    }
  }

  void tipoR(int funct3, int funct7) {
    ulaSrcB = false;        // Entrada B da ULA recebe rs2 (Entrada A já é rs1)
    regWrite = true;        // Libera gravação no rd
    resultSrc = RESULT_ULA; // MUX de Write-Back seleciona o resultado da ULA

    switch (funct3) {
      // add / sub
      case 0x00: {
        if (funct7 == 0x20) {
          print("Tipo R - sub, subtrai rs2 de rs1 e salva em rd.");
          ulaOp = Ula.OP_SUB; // ULA calcula rs1 - rs2
          break;
        } else if (funct7 == 0x00) {
          print("Tipo R - add, soma rs1 com rs2 e salva em rd.");
          ulaOp = Ula.OP_ADD; // ULA calcula rs1 + rs2
          break;
        }

        throw Exception("funct7 desconhecido ou instrução inválida para Tipo-R: ${funct7.toRadixString(16)}");
      }

      // sll
      case 0x01: {
        print("Tipo R - sll, desloca rs1 à esquerda pelos 5 bits inferiores de rs2 e salva em rd.");
        ulaOp = Ula.OP_SLL; // ULA calcula rs1 << (rs2 & 0x1F)
        break;
      }

      // slt
      case 0x02: {
        print("Tipo R - slt, compara rs1 < rs2 (com sinal) e salva 1 ou 0 em rd.");
        ulaOp = Ula.OP_SLT; // ULA compara com sinal
        break;
      }

      // sltu
      case 0x03: {
        print("Tipo R - sltu, compara rs1 < rs2 (sem sinal) e salva 1 ou 0 em rd.");
        ulaOp = Ula.OP_SLTU; // ULA compara sem sinal
        break;
      }

      // xor
      case 0x04: {
        print("Tipo R - xor, faz XOR bit a bit entre rs1 e rs2 e salva em rd.");
        ulaOp = Ula.OP_XOR; // ULA calcula rs1 ^ rs2
        break;
      }

      // srl / sra
      case 0x05: {
        if (funct7 == 0x20) {
          print("Tipo R - sra, deslocamento aritmético à direita (mantém sinal) e salva em rd.");
          ulaOp = Ula.OP_SRA; // ULA calcula rs1 >> (rs2 & 0x1F)
          break;
        } else if (funct7 == 0x00) {
          print("Tipo R - srl, deslocamento lógico à direita (preenche com 0) e salva em rd.");
          ulaOp = Ula.OP_SRL; // ULA calcula rs1 >>> (rs2 & 0x1F)
          break;
        }
        throw Exception("funct7 desconhecido ou instrução inválida para Tipo-R: ${funct7.toRadixString(16)}");
      }

      // or
      case 0x06: {
        print("Tipo R - or, faz OR bit a bit entre rs1 e rs2 e salva em rd.");
        ulaOp = Ula.OP_OR; // ULA calcula rs1 | rs2
        break;
      }

      // and
      case 0x07: {
        print("Tipo R - and, faz AND bit a bit entre rs1 e rs2 e salva em rd.");
        ulaOp = Ula.OP_AND; // ULA calcula rs1 & rs2
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