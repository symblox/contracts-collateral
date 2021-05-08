// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "../interfaces/synth/ICollateral.sol";
import "../tokens/BaseToken.sol";
import "./Connector.sol";

contract ConnectorFactory is Initializable {
    // user address => connector address
    mapping(address => address) public connectors;

    address public collateral;

    event LogCreateConnector(address indexed caller, address connector);

    function __ConnectorFactory_init(address _collateral) public initializer {
        require(_collateral != address(0), "ERR_COLLATERAL");
        collateral = _collateral;
    }

    function createConnector(address syUSD) public returns (address) {
        require(connectors[msg.sender] == address(0), "ERR_CONNECTOR_EXISTED");
        Connector newContract = new Connector(msg.sender, ICollateral(collateral), syUSD);
        require(address(newContract) != address(0), "ERR_CREATE_PROXY");
        address newAddress = address(newContract);
        connectors[msg.sender] = newAddress;
        emit LogCreateConnector(msg.sender, newAddress);

        return newAddress;
    }
}
