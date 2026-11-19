class Ula {

  static const int OP_ADD  = 0;
  static const int OP_SUB  = 1;
  static const int OP_AND  = 2;
  static const int OP_OR   = 3;
  static const int OP_XOR  = 4;
  static const int OP_SLL  = 5; //Shift Left (Deslocamento para esquerda)
  static const int OP_SRL  = 6; //Shift Right Logical (Deslocamento lógico direita)
  static const int OP_SRA  = 7; //Shift Right Arithmetic (Deslocamento aritmético direita)
  static const int OP_SLT  = 8; //Set Less Than (Compara com sinal)
  static const int OP_SLTU = 9; //Set Less Than Unsigned (Compara sem sinal)

  int resultado = 0;
  bool bitflag = false; 

  void executar(int operandoA, int operandoB, int imm, bool ulaSrc, int operacao) {

    int a = operandoA.toSigned(32);
    int b = 0;

    if(ulaSrc == false){
      b = operandoB.toSigned(32);

    } else if(ulaSrc == true){
      b = imm.toSigned(32);

    }
    
    switch (operacao) {
      case OP_ADD:
        resultado = (a + b).toSigned(32);
        break;
        
      case OP_SUB:
        resultado = (a - b).toSigned(32);
        break;
        
      case OP_AND:
        resultado = (a & b).toSigned(32);
        break;
        
      case OP_OR:
        resultado = (a | b).toSigned(32);
        break;
        
      case OP_XOR:
        resultado = (a ^ b).toSigned(32);
        break;
        
      case OP_SLL:
        //No RISC-V RV32, o deslocamento só usa os 5 bits inferiores do Operando B
        int shamt = b & 0x1F;
        resultado = (a << shamt).toSigned(32);
        break;
        
      case OP_SRL:
        int shamt = b & 0x1F;
        //>>> é o Shift Lógico no Dart (preenche com zeros à esquerda)
        resultado = (a.toUnsigned(32) >>> shamt).toSigned(32);
        break;
        
      case OP_SRA:
        int shamt = b & 0x1F;
        //>> é o Shift Aritmético no Dart (preserva o sinal preenchendo com 1s ou 0s)
        resultado = (a >> shamt).toSigned(32);
        break;
        
      case OP_SLT:
        //Se A for menor que B (considerando negativos), resultado é 1, senão 0
        resultado = (a < b) ? 1 : 0;
        break;
        
      case OP_SLTU:
        //Compara A e B como números inteiros puramente positivos
        resultado = (a.toUnsigned(32) < b.toUnsigned(32)) ? 1 : 0;
        break;
        
      default:
        throw Exception("Operação da ULA desconhecida: $operacao");
    }

    //Atualiza o Bitflag (Zero Flag). 
    //***É isso que as instruções Tipo-B (Branches) usam para decidir se pulam ou não
    bitflag = (resultado == 0);
  }
}

void main(List<String> args) {
  var ula = Ula();


  ula.executar(11, 21, 0, false, Ula.OP_ADD);
  print(ula.resultado);
}