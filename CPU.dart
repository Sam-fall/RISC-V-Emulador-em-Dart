import 'ControlUnit.dart';
import 'Barramento.dart';
import 'ImmediateGenerator.dart';
import 'Register.dart';
import 'Ula.dart';

class Cpu {
  int pc = 0; // Program Counter (começa no endereço 0x00000)
  int contadorInstrucoes = 0; // Conta instruções para disparar E/S programada
  int intervaloVRAM; // A cada N instruções executadas, imprime a VRAM
  bool executando = true; // Flag para controlar o loop principal da CPU

  final ControlUnit controlUnit = ControlUnit();
  final Barramento barramento = Barramento();
  final Register register = Register();
  final Ula ula = Ula();

  Cpu({this.intervaloVRAM = 10});

  // Roda o processador continuamente até encontrar 0x00000000 ou ser interrompido
  void executar() {
    executando = true;
    while (executando) {
      cicloDeClock();
    }
    // Imprime a VRAM uma última vez ao finalizar o programa
    barramento.imprimirVRAM();
  }

  // Executa 1 instrução por ciclo
  void cicloDeClock() {
    //FETCH (Busca da instrução na memória)
    int instruction = barramento.lerInstrucao(pc);
    print("Ciclo $contadorInstrucoes | PC: 0x${pc.toRadixString(16)} | Inst: 0x${instruction.toUnsigned(32).toRadixString(16)}");

    // Se encontrar palavra zerada (fim do programa), encerra a execução
    if (instruction == 0) {
      executando = false;
      return;
    }

    // Decoder (Decodificação e leitura de registradores)
    controlUnit.Opcode(instruction);

    int rd  = (instruction >> 7) & 0x1F;
    int rs1 = (instruction >> 15) & 0x1F;
    int rs2 = (instruction >> 20) & 0x1F;

    int dadoA = register.read(rs1);
    int dadoB = register.read(rs2);
    int imm   = ImmGen.gerar(instruction);

    // Executar (ULA)
    // MUX da Entrada A: true = PC (AUIPC) | false = rs1
    int entradaA = controlUnit.ulaSrcA ? pc : dadoA;

    // A própria ULA resolve o MUX da Entrada B usando controlUnit.ulaSrcB
    ula.executar(entradaA, dadoB, imm, controlUnit.ulaSrcB, controlUnit.ulaOp);

    // Memory (Acesso ao Barramento: Loads e Stores)
    int dadoMemoria = 0;

    if (controlUnit.memRead) {
      dadoMemoria = barramento.read(ula.resultado, controlUnit.funct3);
    }

    if (controlUnit.memWrite) {
      barramento.write(ula.resultado, dadoB, controlUnit.funct3);
    }

    //Write-back (Gravação no rd com suporte ao CMOV)
    bool permitirEscrita = controlUnit.regWrite && (!controlUnit.isCmov || dadoB != 0);

    if (permitirEscrita) {
      int valorParaGravar = 0;

      switch (controlUnit.resultSrc) {
        case ControlUnit.RESULT_ULA:
          valorParaGravar = ula.resultado;
          break;
        case ControlUnit.RESULT_MEM:
          valorParaGravar = dadoMemoria;
          break;
        case ControlUnit.RESULT_PC4:
          valorParaGravar = (pc + 4).toSigned(32);
          break;
        case ControlUnit.RESULT_IMM:
          valorParaGravar = imm;
          break;
        case ControlUnit.RESULT_RS1:
          valorParaGravar = dadoA; // CMOV: copia rs1 direto para rd
          break;
      }

      register.write(rd, valorParaGravar);
    }

    // Atualização do PC (Jumps, Branches ou PC + 4)
    if (controlUnit.jump) {
      if (controlUnit.isJalr) {
        // JALR: (rs1 + imm) com bit 0 forçado para 0
        pc = ula.resultado & ~1;
      } else {
        // JAL: PC + imm
        pc = pc + imm;
      }
    } else if (controlUnit.branch) {
      bool desvioTomado = false;

      switch (controlUnit.funct3) {
        case 0x0: // beq (rs1 == rs2 -> ula.resultado == 0)
          desvioTomado = ula.bitflag;
          break;
        case 0x1: // bne (rs1 != rs2 -> ula.resultado != 0)
          desvioTomado = !ula.bitflag;
          break;
        case 0x4: // blt (rs1 < rs2 com sinal -> ula.resultado == 1)
        case 0x6: // bltu (rs1 < rs2 sem sinal -> ula.resultado == 1)
          desvioTomado = (ula.resultado == 1);
          break;
        case 0x5: // bge (rs1 >= rs2 com sinal -> ula.resultado == 0)
        case 0x7: // bgeu (rs1 >= rs2 sem sinal -> ula.resultado == 0)
          desvioTomado = (ula.resultado == 0);
          break;
      }

      pc = desvioTomado ? (pc + imm) : (pc + 4);
    } else {
      pc = pc + 4;
    }

    // E/S PROGRAMADA (VRAM a cada N instruções)
    contadorInstrucoes++;
    if (intervaloVRAM > 0 && contadorInstrucoes % intervaloVRAM == 0) {
      barramento.imprimirVRAM();
    }
  }
}