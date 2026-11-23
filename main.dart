import 'CPU.dart';

void main() {
  final cpu = Cpu(intervaloVRAM: 100);

  // =========================================================
  // 1. SEÇÃO .rodata (.LC0) em 0x01010
  //    %hi(0x01010) = 0x00001000 | %lo(0x01010) = 0x10 (16)
  // =========================================================
  const int enderecoLC0 = 0x01010;
  const String textoFormato = "A soma de %d + %d = %d\n";

  for (int i = 0; i < textoFormato.length; i++) {
    cpu.barramento.write(enderecoLC0 + i, textoFormato.codeUnitAt(i), 0x0); // sb
  }
  cpu.barramento.write(enderecoLC0 + textoFormato.length, 0, 0x0); // '\0'

  // =========================================================
  // 2. SEÇÃO .text — Função main() em 0x00000
  //    Tradução exata 1-para-1 do seu Assembly RV32I
  // =========================================================
  final List<int> programaMain = [
    // Prólogo
    0xFE010113, // 0x0000: addi sp, sp, -32
    0x00112E23, // 0x0004: sw   ra, 28(sp)
    0x00812C23, // 0x0008: sw   s0, 24(sp)
    0x02010413, // 0x000C: addi s0, sp, 32

    // int a = 4;
    0x00400293, // 0x0010: addi t0, zero, 4     (li t0, 4)
    0xFE542623, // 0x0014: sw   t0, -20(s0)

    // int b = 6;
    0x00600293, // 0x0018: addi t0, zero, 6     (li t0, 6)
    0xFE542423, // 0x001C: sw   t0, -24(s0)

    // int c = a + b;
    0xFEC42303, // 0x0020: lw   t1, -20(s0)
    0xFE842383, // 0x0024: lw   t2, -24(s0)
    0x007302B3, // 0x0028: add  t0, t1, t2
    0xFE542223, // 0x002C: sw   t0, -28(s0)

    // Preparação dos argumentos para printf(a0, a1, a2, a3)
    0x00001537, // 0x0030: lui  a0, 0x1         (%hi(.LC0) = 0x01000)
    0x01050513, // 0x0034: addi a0, a0, 0x10    (%lo(.LC0) = +0x10 -> 0x01010)
    0xFEC42583, // 0x0038: lw   a1, -20(s0)     (a = 4)
    0xFE842603, // 0x003C: lw   a2, -24(s0)     (b = 6)
    0xFE442683, // 0x0040: lw   a3, -28(s0)     (c = 10)
    0x0BC000EF, // 0x0044: jal  ra, 0x00100     (call printf)

    // return 0; e Epílogo
    0x00000513, // 0x0048: addi a0, zero, 0     (li a0, 0)
    0x01C12083, // 0x004C: lw   ra, 28(sp)
    0x01812403, // 0x0050: lw   s0, 24(sp)
    0x02010113, // 0x0054: addi sp, sp, 32
    0x00008067, // 0x0058: jalr zero, 0(ra)     (ret)
  ];

  // =========================================================
  // 3. MINI-PRINTF EM RV32I PURO em 0x00100
  //    Lê fmt (a0), formata %d (a1..a3) e grava ASCII na VRAM (0x80000)
  // =========================================================
  final List<int> rotinaPrintf = [
    0xFE010113, // 0x0100: addi sp, sp, -32
    0x00B12023, // 0x0104: sw   a1, 0(sp)
    0x00C12223, // 0x0108: sw   a2, 4(sp)
    0x00D12423, // 0x010C: sw   a3, 8(sp)
    0x000802B7, // 0x0110: lui  t0, 0x80        (t0 = 0x80000, início da VRAM)
    0x00010393, // 0x0114: addi t2, sp, 0       (t2 = ponteiro para args na pilha)
    // loop:
    0x00054303, // 0x0118: lbu  t1, 0(a0)       (lê caractere atual da string)
    0x08030463, // 0x011C: beq  t1, zero, done  (se '\0', termina)
    0x02500E93, // 0x0120: addi t4, zero, 37    (37 = '%')
    0x01D30A63, // 0x0124: beq  t1, t4, fmt_d   (se '%', formata inteiro)
    0x00628023, // 0x0128: sb   t1, 0(t0)       (grava char na VRAM)
    0x00128293, // 0x012C: addi t0, t0, 1
    0x00150513, // 0x0130: addi a0, a0, 1
    0xFE5FF06F, // 0x0134: jal  zero, loop
    // fmt_d:
    0x00250513, // 0x0138: addi a0, a0, 2       (pula "%d")
    0x0003AE03, // 0x013C: lw   t3, 0(t2)       (carrega próximo argumento)
    0x00438393, // 0x0140: addi t2, t2, 4
    0x000E5A63, // 0x0144: bge  t3, zero, pos   (se >= 0, pula sinal '-')
    0x02D00313, // 0x0148: addi t1, zero, 45    (45 = '-')
    0x00628023, // 0x014C: sb   t1, 0(t0)
    0x00128293, // 0x0150: addi t0, t0, 1
    0x41C00E33, // 0x0154: sub  t3, zero, t3    (t3 = -t3)
    // pos:
    0x01010F93, // 0x0158: addi t6, sp, 16      (base do buffer temporário de dígitos)
    0x000F8F13, // 0x015C: addi t5, t6, 0
    // div_outer: (converte para base 10 por subtrações sucessivas de 10)
    0x00000E93, // 0x0160: addi t4, zero, 0     (quociente = 0)
    0x00A00313, // 0x0164: addi t1, zero, 10
    // div_loop:
    0x006E4863, // 0x0168: blt  t3, t1, div_done
    0x406E0E33, // 0x016C: sub  t3, t3, t1
    0x001E8E93, // 0x0170: addi t4, t4, 1
    0xFF5FF06F, // 0x0174: jal  zero, div_loop
    // div_done:
    0x030E0E13, // 0x0178: addi t3, t3, 48      (resto + '0')
    0x01CF0023, // 0x017C: sb   t3, 0(t5)
    0x001F0F13, // 0x0180: addi t5, t5, 1
    0x000E8E13, // 0x0184: addi t3, t4, 0
    0xFC0E1CE3, // 0x0188: bne  t3, zero, div_outer
    // print_digits: (desempilha dígitos na ordem correta para a VRAM)
    0xFFFF0F13, // 0x018C: addi t5, t5, -1
    0x000F4303, // 0x0190: lbu  t1, 0(t5)
    0x00628023, // 0x0194: sb   t1, 0(t0)
    0x00128293, // 0x0198: addi t0, t0, 1
    0xFFFF18E3, // 0x019C: bne  t5, t6, print_digits
    0xF79FF06F, // 0x01A0: jal  zero, loop
    // done:
    0x02010113, // 0x01A4: addi sp, sp, 32
    0x00008067, // 0x01A8: jalr zero, 0(ra)     (ret)
  ];

  // Carrega os blocos na RAM
  cpu.barramento.carregarPrograma(programaMain, enderecoInicial: 0x00000);
  cpu.barramento.carregarPrograma(rotinaPrintf, enderecoInicial: 0x00100);

  // Inicializa registradores de sistema (sp no topo da RAM, ra em endereço zerado)
  cpu.register.write(2, 0x7FFF0); // sp (x2) = topo da RAM alinhado em 16 bytes
  cpu.register.write(1, 0x02000); // ra (x1) = endereço com 0x00000000 para encerrar no 'ret'

  // Executa o simulador
  cpu.executar();

  print("Execução finalizada em ${cpu.contadorInstrucoes} ciclos.");
  print("Retorno de main (a0): ${cpu.register.read(10)}");
  print("Stack Pointer final (sp): 0x${cpu.register.read(2).toRadixString(16)}");
}