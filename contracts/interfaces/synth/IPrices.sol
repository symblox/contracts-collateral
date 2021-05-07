// SPDX-License-Identifier: MIT
pragma solidity >=0.4.24;

// a facade for prices fetch from oracles
interface IPrices {
    // get price for a currency
    function getPrice(bytes32 currencyName) external view returns (uint256);

    // get price and updated time for a currency
    function getPriceAndUpdatedTime(bytes32 currencyName) external view returns (uint256 price, uint256 time);

    // is the price is stale
    function isStale(bytes32 currencyName) external view returns (bool);

    // the defined stale time
    function stalePeriod() external view returns (uint256);

    // exchange amount of source currenty for some dest currency, also get source and dest curreny price
    function exchange(
        bytes32 sourceName,
        uint256 sourceAmount,
        bytes32 destName
    ) external view returns (uint256);

    // exchange amount of source currenty for some dest currency
    function exchangeAndPrices(
        bytes32 sourceName,
        uint256 sourceAmount,
        bytes32 destName
    )
        external
        view
        returns (
            uint256 value,
            uint256 sourcePrice,
            uint256 destPrice
        );

    // price names
    function LUSD() external view returns (bytes32);
}
