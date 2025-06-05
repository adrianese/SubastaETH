// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Subasta {
    // Variables de Estado
    // VARIABLES PUBLICAS
    bool public auctionEnded;         // auctionEnded: Indica si la subasta ha terminado.
    
    // VARIABLES PRIVADAS
    address private owner;            // owner: Direccion del creador del contrato.
    uint private endTime;             // endTime: Marca de tiempo de finalizacion de la subasta.
    uint public highestBid;           // highestBid: Monto de la oferta mas alta actual.
    address private highestBidder;    // highestBidder: Direccion del apostador con la oferta mas alta.
    mapping(address => uint) private bids; // bids: Mapeo que almacena el deposito de cada apostador.
    address[] private biddersList;    // biddersList: Arreglo dinamico de direcciones de apostadores.
    
    // Estructura para guardar una oferta
    struct Oferta {
        address apostador;
        uint monto;
    }
    
    // EVENTOS
    // NuevaOferta: Se emite cuando se realiza una nueva oferta.
    event NuevaOferta(address indexed apostador, uint monto);
    
    // SubastaFinalizada: Se emite cuando se finaliza la subasta.
    event SubastaFinalizada(address ganador, uint monto);
    
    // ReembolsoEmitido: Se emite cuando se realiza un reembolso a un apostador.
    event ReembolsoEmitido(address indexed apostador, uint montoReembolsado);
    
    // CONSTRUCTOR: Inicializa el contrato con una duracion de la subasta.
    constructor(uint _duracion) {
        owner = msg.sender;
        endTime = block.timestamp + _duracion; // Duracion de la subasta en segundos.
        auctionEnded = false;
    }
    
    // MODIFICADORES
    /**
     * @notice Permite la ejecucion solo antes de la hora de fin de la subasta.
     */
    modifier soloAntesDeFin() {
        require(block.timestamp < endTime, "La subasta ya ha terminado");
        _;
    }
    
    /**
     * @notice Garantiza que la subasta aun no ha terminado.
     */
    modifier subastaNoTerminada() {
        require(!auctionEnded, "La subasta ya ha terminado");
        _;
    }
    
    /**
     * @notice Permite la ejecucion solo despues de que la subasta se haya terminado.
     */
    modifier soloDespuesDeSubastaTerminada() {
        require(auctionEnded, "La subasta aun no ha terminado");
        _;
    }
    
    // FUNCION: finalizarSubasta
    /**
     * @notice Finaliza la subasta y emite un evento.
     * @dev Solo se puede llamar si ya ha pasado la duracion de la subasta.
     */
    function finalizarSubasta() external subastaNoTerminada {
        require(block.timestamp > endTime, "La subasta aun esta activa.");
        auctionEnded = true;
        emit SubastaFinalizada(highestBidder, highestBid);
    }
    
    // FUNCION: obtenerGanador
    /**
     * @notice Retorna el apostador con la oferta mas alta y el monto de la oferta ganadora.
     * @return ganador Direccion del apostador ganador.
     * @return monto Monto de la oferta ganadora.
     */
    function obtenerGanador() external view returns (address, uint) {
        require(auctionEnded, "La subasta aun no ha terminado.");
        return (highestBidder, highestBid);
    }
    
    // FUNCION: nuevaOferta
    /**
     * @notice Permite a los participantes enviar una oferta; valida las condiciones de oferta y limites de tiempo.
     * @dev La oferta debe ser mayor que cero y al menos 5% mayor que la oferta mas alta actual.
     *      Si el apostador es nuevo, se agrega su direccion al arreglo de apostadores.
     */
    function nuevaOferta() external payable soloAntesDeFin subastaNoTerminada { 
        require(msg.value > 0, "El monto de la oferta debe ser mayor que cero");
        require(msg.value >= (highestBid * 105) / 100, "La oferta debe ser al menos 5% mayor que la oferta mas alta");
        
        if (bids[msg.sender] == 0) {
            biddersList.push(msg.sender); // Agregar apostador si oferta por primera vez.
        }
        
        bids[msg.sender] += msg.value;
        
        highestBidder = msg.sender;
        highestBid = msg.value;
        
        emit NuevaOferta(msg.sender, msg.value);
    }
    
    // FUNCION: obtenerOfertas
    /**
     * @notice Provee informacion sobre todas las ofertas realizadas.
     * @return Una tupla que contiene un arreglo de direcciones de apostadores y un arreglo con sus respectivos montos de oferta.
     */
    function obtenerOfertas() external view returns (address[] memory, uint[] memory) {
        uint totalBids = biddersList.length;
        
        address[] memory apostadores = new address[](totalBids);
        uint[] memory montos = new uint[](totalBids);
        
        for (uint i = 0; i < totalBids; i++) {
            address apostador = biddersList[i];
            apostadores[i] = apostador;
            montos[i] = bids[apostador];
        }
        
        return (apostadores, montos);
    }
    
    // FUNCION: reembolsoParcial
    /**
     * @notice Permite a los apostadores no ganadores retirar sus depositos.
     * @dev El apostador con la oferta mas alta (ganador) no puede retirar fondos excedentes.
     *      Se deduce una tarifa del 2% del monto del reembolso.
     */
    function reembolsoParcial() external payable subastaNoTerminada {
        uint amount = bids[msg.sender];
        require(amount > 0, "No hay depositos disponibles para retirar.");
        require(msg.sender != highestBidder, "El ganador no puede retirar fondos excedentes.");
        
        bids[msg.sender] = 0; // Previene reentradas.
        uint refund = (amount * 98) / 100; // Deducir una tarifa del 2%.
        payable(msg.sender).transfer(refund);
    }
    
    // FUNCION: reembolsarTodosNoGanadores
    /**
     * @notice Reembolsa automaticamente a todos los apostadores no ganadores una vez finalizada la subasta.
     * @dev Itera sobre el arreglo de apostadores y emite reembolsos (despues de deducir una tarifa del 2%)
     *      a todos aquellos que no sean el apostador con la oferta mas alta.
     */
    function reembolsarTodosNoGanadores() external soloDespuesDeSubastaTerminada {
        uint totalApostadores = biddersList.length;
        
        for (uint i = 0; i < totalApostadores; i++) {
            address apostador = biddersList[i];
            
            if (apostador != highestBidder && bids[apostador] > 0) {
                uint refundAmount = (bids[apostador] * 98) / 100; // Aplicar tarifa del 2%.
                bids[apostador] = 0; // Previene reentradas poniendo el deposito a cero.
                payable(apostador).transfer(refundAmount);
                
                emit ReembolsoEmitido(apostador, refundAmount);
            }
        }
    }
}