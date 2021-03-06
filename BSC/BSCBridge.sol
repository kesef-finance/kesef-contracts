pragma solidity 0.7.3;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/cryptography/ECDSA.sol';
import './Token.sol';
import './TransferHelper.sol';

contract BSCBridge is Ownable {
    using SafeMath for uint;
    
    address public signer;

    mapping(address => uint256) public portFee;
    mapping(string => bool) public executed;
    mapping(address => address) public ercToBep;
    mapping(address => address) public bepToErc;

    event PortTo(address indexed bepToken, address indexed ercToken, address indexed from, uint256 amount);
    event PortBack(address indexed ercToken, address indexed bepToken, address indexed from, uint256 amount, string _portTxHash);

    constructor(address _signer) public {
        require(_signer != address(0x0));
        signer = _signer;
    }

    function withdrawFee(address _token, address _to, uint256 _amount) onlyOwner external {
        require(_to != address(0), "invalid address");
        require(_amount > 0, "amount must be greater than 0");
        if(_token == address(0))
        TransferHelper.safeTransferETH(_to, _amount);
        else TransferHelper.safeTransfer(_token, _to, _amount);
    }

    function portTo(address _bepToken, uint256 _amount) external payable {
        address ercToken = bepToErc[_bepToken]; // ensure we support swap
        require(ercToken != address(0), "invalid token");
        require(_amount > 0, "amount must be greater than 0");
        require(portFee[ercToken] == msg.value, "invalid port fee");
        
        Token(_bepToken).burn(msg.sender, _amount);
        emit PortTo(_bepToken, ercToken, msg.sender, _amount);
    }

    // signature for authorization of mint
    function portBack(bytes calldata _signature, string memory _portTxHash, address _ercToken, uint _amount) external {
        require(!executed[_portTxHash], "already ported back");
        require(_amount > 0, "amount must be greater than 0");
        address bepToken = ercToBep[_ercToken];

        uint chainId;
        assembly {
            chainId := chainid()
        }
        bytes32 message = keccak256(abi.encodePacked(chainId, address(this), _ercToken, _amount, msg.sender, _portTxHash));
        bytes32 signature = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
       
        require(ECDSA.recover(signature, _signature) == signer, "invalid signature");

        executed[_portTxHash] = true;
        Token(bepToken).mint(msg.sender, _amount);
        emit PortBack(_ercToken, bepToken, msg.sender, _amount, _portTxHash);
    }

    function changePortFee(address ercToken, uint256 _portFee) onlyOwner external {
        portFee[ercToken] = _portFee;
    }

    function changeSigner(address _signer) onlyOwner external {
        signer = _signer;
    }

    function addToken(address _ercToken, address _bepToken) onlyOwner external {
        ercToBep[_ercToken] = _bepToken;
        bepToErc[_bepToken] = _ercToken;
    }
}