// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {FlashLoanSimpleReceiverBase} from "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20Detailed} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20Detailed.sol";

interface IController {
    struct ProfitParams {
        address userAddress;
        uint256 profitUSD;
        uint256 borrowedValueinUSD;
    }
    function updateProfit(ProfitParams memory params) external returns(bool);
    function checkUserRole(address account) external view returns (bool);
    function checkDEFAULTADMINRole(address account) external view returns (bool);
    function checkADMINRole(address account) external view returns (bool);

}



contract FlashBot is FlashLoanSimpleReceiverBase {

    event FUNDTransferred(address account, uint256 amount);
    event SignControllerchanged(address prevSigner, address newSigner);
    event Controllerchanged(address prevController, address newController);

    //@notice Signer the event is emited at the time of changeSigner function invoke. 
    //@param previousSigner address of the previous contract owner.
    //@param newSigner address of the new contract owner.

    event SignerChanged(
        address signer,
        address newOwner
    );

    //@notice Sign struct stores the sign bytes
    //@param v it holds(129-130) from sign value length always 27/28.
    //@param r it holds(0-66) from sign value length.
    //@param s it holds(67-128) from sign value length.
    //@param nonce unique value.

    struct Sign{
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 nonce;
    }

    enum dexList {
        ZERO_X,
        OPENOCEAN,
        ONEINCH,
        PARASWAP
    }

    uint256 public totalTradelimit = 0;
    uint256 public totalProfit = 0;
    uint256 public totalTxns = 0;



    struct LoanParams {
        address[] tokenAddress;
        uint256 profitValue;
        uint256 borrowedValue;
        uint256 amount;
        uint8[] dexPath;
        bytes[] swapCalldata;
    }

    struct BLoanParams {
        address[] tokenAddress;
        address caller;
        uint256 profitValue;
        uint256 borrowedValue;
        uint256 amount;
        uint8[] dexPath;
        bytes[] swapCalldata;
    }

    address ZERO_X_ADDRESS;
    address ONEINCHADDRESS;
    address OPENOCEANADDRESS;
    address PARASWAPADDRESS;

    address public Controller;

    address public signController;

    LoanParams internal  Loan_params;
    BLoanParams internal BLoan_params;

    Type callType;

    enum Type {USER, BOT }


    mapping (bytes32 => bool) public isValidSign;

    mapping(uint8 => address) internal DexAddresses;

    address paraswapProxy = 0x216B4B4Ba9F3e719726886d34a177484278Bfcae;


    modifier onlyUSERRole() {
        require(IController(Controller).checkUserRole(msg.sender), "FlashController: account not whitelisted");
        _;
    }

    modifier onlyDEFAULTADMINRole() {
        require(IController(Controller).checkDEFAULTADMINRole(msg.sender), "FlashController: invalid ADMIN account");
        _;
    }
    
    modifier onlyADMINRole() {
        require(IController(Controller).checkADMINRole(msg.sender), "FlashController: invalid ADMIN account");
        _;
    }

    constructor(address _addressProvider, address _ZERO_X_ADDRESS,address _ONEINCHADDRESS, address _OPENOCEANADDRESS, address _PARASWAPADDRESS, address _Controller, address _signer) 
        FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider))
    {
       Controller = _Controller;
       signController = _signer;
       DexAddresses[0] = _ZERO_X_ADDRESS;
       DexAddresses[1] = _ONEINCHADDRESS;
       DexAddresses[2] = _OPENOCEANADDRESS;
       DexAddresses[3] = _PARASWAPADDRESS;

    }

    function updatesPlatformStats(uint256 txns, uint256 profits, uint256 tradeVolume) external onlyADMINRole() {
        totalTradelimit = tradeVolume;
        totalProfit = profits;
        totalTxns = txns;
    }

    function changeSignController(address newSigner) external onlyADMINRole() {
        require(newSigner != address(0), "Invalid signer address");
        address temp = signController;
        signController = newSigner;
        emit SignControllerchanged(temp, newSigner);
    }

    function changeController(address newController) external onlyADMINRole() {
        require(newController != address(0), "Invalid signer address");
        address temp = Controller;
        Controller = newController;
        emit Controllerchanged(temp, Controller);
    }

    function withdrawFunds(address token, uint256 amount) external  onlyDEFAULTADMINRole() returns(bool) {
        require(amount !=0, "Controller: amount should be greater than zero");
        bool status = IERC20Detailed(token).transfer(msg.sender, amount);
        emit FUNDTransferred(token, amount);
        return  status;
    }

    function swapTokens(LoanParams memory params, uint256 premium) internal {
        require((params.swapCalldata.length) == params.dexPath.length, "invalid trx");
        require(approve(params.dexPath, params.tokenAddress), "approve failed");
        uint256 borrowed = params.amount;
        for (uint i = 0; i < params.dexPath.length; i++)
        {
            params.amount = calldataSwap(DexAddresses[params.dexPath[i]], params.swapCalldata[i]);
        }
        require(params.amount > (borrowed + premium),"Non-Profitable trade");
        if(params.amount > (borrowed + premium)) {
            uint256 profit = params.amount - (borrowed + premium);
            IERC20Detailed(params.tokenAddress[0]).transfer(tx.origin, profit);
        }

    }

    function botSwapTokens(BLoanParams memory bparams, uint256 premium) internal {
        require((bparams.swapCalldata.length) ==bparams.dexPath.length, "invalid trx");
        require(approve(bparams.dexPath, bparams.tokenAddress), "approve failed");
        uint256 borrowed = bparams.amount;
        for (uint i = 0; i < bparams.dexPath.length; i++)
        {
            bparams.amount = calldataSwap(DexAddresses[bparams.dexPath[i]], bparams.swapCalldata[i]);
        }
        require(bparams.amount > (borrowed + premium),"Non-Profitable trade");
        if(bparams.amount > (borrowed + premium)) {
            uint256 profit = bparams.amount - (borrowed + premium);
            IERC20Detailed(bparams.tokenAddress[0]).transfer(bparams.caller, profit);
        }

    }

    function calldataSwap(address swapTarget, bytes memory swapCallData) internal returns(uint256)  {
        (bool success, bytes memory amountOut) = swapTarget.call(swapCallData);
        require(success, 'SWAP_CALL_FAILED');
        return abi.decode(amountOut, (uint256));
    }
    
    function approve(uint8[] memory swapTarget, address[] memory tokenIn) internal returns(bool status){
        for (uint8 index = 0; index < swapTarget.length; index ++) 
        {
            if(swapTarget[index] == 3) {
                require(IERC20Detailed(tokenIn[index]).approve(paraswapProxy, type(uint256).max));
            }
            require(IERC20Detailed(tokenIn[index]).approve(DexAddresses[swapTarget[index]], type(uint256).max));
        }
        return  true;
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        if(Type.USER == callType) {
        swapTokens(Loan_params, premium);
        }
        if(Type.BOT == callType) {
        botSwapTokens(BLoan_params, premium);
        }
        uint256 amountOwed = amount + premium;
        IERC20Detailed(asset).approve(address(POOL), amountOwed);
        return true;
    }

    function requestFlashLoan(LoanParams calldata lparams, Sign calldata sign) public {
        verifySign(msg.sender, lparams.tokenAddress[0], lparams.amount,sign);
        address receiverAddress = address(this);
        address asset = lparams.tokenAddress[0];
        bytes memory params = "";
        uint16 referralCode = 0;
        Loan_params = lparams;
        callType = Type.USER;
        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            lparams.amount,
            params,
            referralCode
        );
        IController.ProfitParams memory _params = IController.ProfitParams(msg.sender, lparams.profitValue, lparams.borrowedValue);
        IController(Controller).updateProfit(_params);
    }

    function requestFlashLoanForBot(BLoanParams calldata blparams, Sign calldata sign) public {
        verifySign(msg.sender, blparams.tokenAddress[0], blparams.amount,sign);
        address receiverAddress = address(this);
        address asset = blparams.tokenAddress[0];
        bytes memory params = "";
        callType = Type.BOT;
        uint16 referralCode = 0;
        BLoan_params = blparams;
        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            blparams.amount,
            params,
            referralCode
        );
        IController.ProfitParams memory _params = IController.ProfitParams(blparams.caller, blparams.profitValue, blparams.borrowedValue);
        IController(Controller).updateProfit(_params);
    }

    function verifySign(
        address account,
        address bToken,
        uint256 amount,
        Sign memory sign
    ) internal  {
        bytes32 hash = keccak256(
            abi.encodePacked(this, account, bToken, amount,sign.nonce)
        );

        require(
            !isValidSign[hash],
            "Duplicate Sign"
        );

        isValidSign[hash] = true;

        require(
            signController ==
                ecrecover(
                    keccak256(
                        abi.encodePacked(
                            "\x19Ethereum Signed Message:\n32",
                            hash
                        )
                    ),
                    sign.v,
                    sign.r,
                    sign.s
                ),
            "Signer sign verification failed"
        );

    }

    receive() external payable {}
}