pragma solidity ^0.5.0;

import "./merkleProof/Verify.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "./MerkleMintCore.sol";

/**
 * @title MerkleMintController Controller for MerkleProof based Token Minting
 * @dev The ERC721 token is deployed seperately, with MerkleMintController set as an allowed Minter.
 * @dev To mint a token a merkle proof is required. MerkleProofs belong to inidivial Serie with are part of Series.
 * @dev This ensure that each series is limited in quantity, but additional series can be added as required.
 * @dev It is intended that the owner is set as a MultiSig or DAO contract, and the owner can add new series with MerkleRoots.
 * @dev This allows for manageing a token that can assure users that assets belong to a set of defined range.
 */
contract MerkleMintController is Initializable, Ownable, Verify {
    //Address of the NFT Token
    MerkleMintCore public token;

    //Struct that defines a Serie
    //ToDO: If the Series is created properlly with the proper totalTokens there shoudl be no need to check when minting
    //if too many tokens have been minted. Currently add series does not enforce a checking of the mergle tree length, so
    //Users need to be careful to input the correct totalTokens.
    struct Serie {
        bytes32 merkleRoot; //The Merkle root for this series.
        bytes32[] ipfsHash; //The IPFS hash for more information about this series
        string serieName; //The String value name of this Series
        uint256 seriesID; //The ID of this series- an Integer
        uint256 totalTokens; //The Total number of tokens this series can have
        uint256 tokenCount; //The number of tokens that have been minted so far in this series
        mapping(uint256 => uint256) catalogue; //Each token currently minted in the series
    }
    //Maping of Series by integer
    mapping(uint256 => Serie) public series;

    //Mapping associating a token Id to a series
    mapping(uint256 => uint256) public tokenInSeriesRegister;

    /**
     * @dev Event for when a new Serie is added.
     * @param SerieNumber is the Integer of the Serie added. Indexed.
     * @param IPFSHash is the location of the data describing the Serie.
     * @param MerkleRoot of the tree of elements which belong to this Serie. Indexed.
     * @param SerieName is the string version name of the series.
     */
    event SerieAdded(
        uint256 indexed SerieNumber,
        bytes32 IPFSHash,
        bytes32 indexed MerkleRoot,
        string SerieName
    );

    /**
    * @dev Event for when a new IPFS hash is added to the Serie
    * @param SerieNumber is the integer which identifies the Serie. Indexed.
    * @param IPFSHash is the location of the off-chain data which is being added.
    */
    event IPFSHashAdded(uint256 indexed SerieNumber, bytes32 IPFSHash);

    /**
    * @dev Initialized the Controller Contract. Called at deployment time.
    * @param _token is the address of the MerkleMintCore contract.
    */
    function initializeController(MerkleMintCore _token) public initializer {
        Ownable.initialize(msg.sender);
        token = _token;

    }

    /**
    * @dev Add a new merkle Root to a serie.
    * @param _serieNumber is the Serie that a merkle root is being added to.
    * @param _merkleRoot is the merkle root for the serie.
    * @param _serieName is the name of the serie.
    * @param _ipfsHash is the first off-chain data location for the serie. (More can be added seperately)
    * @return emits the SerieAdded event.
    * TODO: Find a way to prevent incorrect total tokens being set.
    */
    function addSerie(
        uint256 _serieNumber,
        bytes32 _merkleRoot,
        string memory _serieName,
        bytes32 _ipfsHash,
        uint256 _totalTokens
    ) public onlyOwner {
        require(
            series[_serieNumber].seriesID == 0,
            "MerkleMintController::addMerkleRoot:: Series already Exists"
        );

        Serie memory serie;
        serie.merkleRoot = _merkleRoot;
        serie.seriesID = _serieNumber;
        serie.serieName = _serieName;
        serie.totalTokens = _totalTokens;
        serie.tokenCount = 0;

        series[_serieNumber] = serie;
        series[_serieNumber].ipfsHash.push(_ipfsHash);
        emit SerieAdded(_serieNumber, _ipfsHash, _merkleRoot, _serieName);
    }

    /**
    * @dev Mint a new Asset (ERC721 Token)
    * @param _asset the intended asset token to mint. This is also the TokensURI
    * @param _leaf required for the merkleproof.
    * @param _proof provided for verification.
    * @param tokenId of the asset token requested to mint. (TODO: Connect this to the minting process)
    * @param _serie that the merkleproof should check against.
    * @return MerkleMintCore will mint a token and emit an event.
    */
    function mintAsset(
        string memory _asset,
        bytes32 _leaf,
        bytes32[] memory _proof,
        uint256 tokenId,
        uint256 _serie
    ) public {
        require(
            isValidData(_asset, _findRoot(_serie), _leaf, _proof),
            "MerkleMintController:: Not a valid Asset"
        );

        uint256 tokenCount = series[_serie].tokenCount;

        series[_serie].tokenCount = tokenCount + 1;
        series[_serie].catalogue[tokenCount] = tokenId;

        token.mintWithTokenURI(address(this), tokenId, _asset);
    }

    /**
    * @dev Function to add a new IPFS reference to a Serie
    * @param _ipfsHash of the off-chain reference to add to the serie.
    * @param _serieNumber of the Serie the hash should be added to.
    */
    function addIpfsRefToSerie(bytes32 _ipfsHash, uint256 _serieNumber) public onlyOwner {
        require(
            series[_serieNumber].seriesID == _serieNumber,
            "MerkleMintController::addIpfsRefToSerie:: Serie does not Exist"
        );

        series[_serieNumber].ipfsHash.push(_ipfsHash);
        emit IPFSHashAdded(_serieNumber, _ipfsHash);
    }

    //Internal function to find the root which accompanies the requested serie.
    function _findRoot(uint256 _serie) internal view returns (bytes32) {
        bytes32 merkleRoot = series[_serie].merkleRoot;
        require(
            merkleRoot != bytes32(0),
            "MerkleMintController::_findRoot:: No such series exists"
        );
        return merkleRoot;
    }
}
