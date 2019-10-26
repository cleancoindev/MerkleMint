pragma solidity ^0.5.0;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/ERC721Enumerable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/ERC721Metadata.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/ERC721MetadataMintable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC721/ERC721Pausable.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract MerkleMintCore is
    Initializable,
    ERC721,
    ERC721Enumerable,
    ERC721Metadata,
    ERC721MetadataMintable,
    ERC721Pausable
{
    address proxyRegistryAddress;

    function initialize(
        address[] memory minters,
        address[] memory pausers,
        address _proxyRegistryAddress
    ) public initializer {
        ERC721.initialize();
        ERC721Enumerable.initialize();
        ERC721Metadata.initialize("MerkleMintToken", "MMT");

        //Setup OpenSea Proxy
        proxyRegistryAddress = _proxyRegistryAddress;

        // Initialize the minter and pauser roles, and renounce them
        ERC721MetadataMintable.initialize(address(this));
        _removeMinter(address(this));

        ERC721Pausable.initialize(address(this));
        _removePauser(address(this));

        // Add the requested minters and pausers (this can be done after renouncing since
        // these are the internal calls)
        for (uint256 i = 0; i < minters.length; ++i) {
            _addMinter(minters[i]);
        }

        for (uint256 i = 0; i < pausers.length; ++i) {
            _addPauser(pausers[i]);
        }
    }

    /**
   * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
   */
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
        if (address(proxyRegistry.proxies(owner)) == operator) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

}
