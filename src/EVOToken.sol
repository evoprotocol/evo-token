// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/// @notice Modern and gas efficient ERC20 + ERC2612 implementation with owner for complex tokenization.
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC20.sol)
contract EVOToken {
    /// -----------------------------------------------------------------------
    /// Events
    /// -----------------------------------------------------------------------

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event OwnershipTransferred(address indexed user, address indexed owner);

    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    error Unauthorized();

    error PermitExpired();

    error InvalidSigner();

    /// -----------------------------------------------------------------------
    /// Metadata Storage
    /// -----------------------------------------------------------------------

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /// -----------------------------------------------------------------------
    /// ERC20 Storage
    /// -----------------------------------------------------------------------

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /// -----------------------------------------------------------------------
    /// ERC2612 Storage/Logic
    /// -----------------------------------------------------------------------

    uint256 private immutable INITIAL_CHAIN_ID;

    bytes32 private immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : _computeDomainSeparator();
    }

    function _computeDomainSeparator() private view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes("INR Coin")),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /// -----------------------------------------------------------------------
    /// Ownership Storage/Logic
    /// -----------------------------------------------------------------------

    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();

        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _owner
    ) payable {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();

        // Prevents common misspending conditions.
        balanceOf[address(this)] = type(uint256).max;
        balanceOf[address(0)] = type(uint256).max;
        
        owner = _owner;
        emit OwnershipTransferred(address(0),_owner);
    }

    /// -----------------------------------------------------------------------
    /// ERC20 Logic
    /// -----------------------------------------------------------------------

    function approve(address spender, uint256 amount) external payable returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) external payable returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external payable returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /// -----------------------------------------------------------------------
    /// ERC2612 Logic
    /// -----------------------------------------------------------------------

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        if (block.timestamp > deadline) revert PermitExpired();

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            if (recoveredAddress == address(0)) revert InvalidSigner();

            if (recoveredAddress != owner) revert InvalidSigner();

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    /// -----------------------------------------------------------------------
    /// Ownership Logic
    /// -----------------------------------------------------------------------

    function transferOwnership(address _owner) external payable onlyOwner {
        owner = _owner;

        emit OwnershipTransferred(msg.sender, _owner);
    }

    /// -----------------------------------------------------------------------
    /// Mint/Burn Logic
    /// -----------------------------------------------------------------------

    function mint(address to, uint256 amount) external payable onlyOwner {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external payable onlyOwner {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

/// @notice EVO Token create2 generator.
contract EVOTokenFactory {
    event Created(
        string name,
        string symbol,
        uint8 decimals,
        address owner,
        bytes32 salt
    );

    function createEVOToken(
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        address owner,
        bytes32 salt
    ) external {
        new EVOToken{salt: salt}(
            name,
            symbol,
            decimals,
            owner
        );

        emit Created(
            name,
            symbol,
            decimals,
            owner,
            salt
        );
    }
}
