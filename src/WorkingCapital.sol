// SPDX-License-Identifier: MIT
// SPDX-License_Identifier: APGL-3.0-or-later

pragma solidity 0.8.17;

import {PluginCloneable, IDAO} from "@aragon/osx/core/plugin/PluginCloneable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {BokkyPooBahsDateTimeLibrary} from "./BokkyPooBahsDateTimeLibrary.sol";
import {IHats} from "./../hatsprotocol/src/Interfaces/IHats.sol";

contract WorkingCapital is PluginCloneable {

    struct MyAction {
        address to;
        uint256 value;
        address ERC20;
    }

    IHats public hatsProtocolInstance;
    uint256 public hatId;
    mapping(address => uint256) public spendingLimit;

    uint private currentMonth;
    uint private currentYear;
    mapping(address => uint256) private remainingBudget;
    address[] availableTokens;

    /// @notice Initializes the contract.
    /// @param _dao The associated DAO.
    /// @param _hatId The id of the hat.
    function initialize(IDAO _dao, uint256 _hatId,address[] _token ,uint256[] _spendingLimit) external initializer {
        __PluginCloneable_init(_dao);
        hatId = _hatId;
        // TODO get this from environment per network (this is goerli)
        hatsProtocolInstance = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137);
        require(_token.length==_spendingLimit.length,"Length of token address and spendingLimit array is not equal");
        spendingLimit = _spendingLimit;
        for (uint j=0; j < _token.length; j+=1) {
            spendingLimit[_token[j]]=_spendingLimit[j];
        }
        availableTokens=_token;
    }


    /// @notice Check that the given token has allowance
    /// @param _token check that given token has allowance
    function isTokenAvailable(address _token) internal pure returns (bool) {
        for (uint256 i = 0; i < availableTokens.length; i++) {
            if (availableTokens[i] == _token) {
                return true;
            }
        }
        return false;
    }


    /// @notice Checking that can user withdraw this amount
    /// @param _actions actions that would be checked
    /// @return generatedDAOActions IDAO.Action generated for use in execute
    function hasRemainingBudget(MyAction[] calldata _actions) internal returns(IDAO.Action[] generatedDAOActions){
        uint _currentMonth = BokkyPooBahsDateTimeLibrary.getMonth(block.timestamp);
        uint _currentYear = BokkyPooBahsDateTimeLibrary.getYear(block.timestamp);
        for (uint j=0; j < _actions.length; j+=1) {
            address _to;
            uint256 _value;
            bytes _data;
            if(_actions[j].ERC20.length == 0){
                _to=_actions[j].to;
                _value=_actions[j].value;
                _data= bytes(0);
            }
            else{
                _to=__actions[j].ERC20;
                _value=0;
                bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", _actions[j].to, _actions[j].value);
                _data= data;
            }
            require(isTokenAvailable(_token),"It is not available token in this plugin");
            // if we are on the month that we were
            if(_currentMonth==currentMonth && _currentYear==currentYear){
                require(
                    remainingBudget[_token]>=_actions[j].value,
                    string.concat("In ",Strings.toString(j)," action you want to spend more than your limit monthly") 
                );
                remainingBudget[_token] -=_actions[j].value;
            }
            // if we are on another month
            else{
                currentYear = _currentYear;
                currentMonth = _currentMonth;
                for (uint j=0; j < availableTokens.length; j+=1) {
                    remainingBudget[availableTokens[j]]=spendingLimit[availableTokens[j]];
                }
                require(
                    remainingBudget[_token]>=_actions[j].value,
                    string.concat("In ",Strings.toString(j)," action you want to spend more than your limit monthly") 
                );
                remainingBudget[_token]-=_actions[j].value;
            }

            generatedDAOActions.push(IDAO.Action(_to, _value, _data));

        }
    }

    //to value token

    /// @notice Executes actions in the associated DAO.
    /// @param _actions The actions to be executed by the DAO.
    function execute(
        MyAction[] calldata _myActions
    ) external {
        require(hatsProtocolInstance.isWearerOfHat(msg.sender, hatId), "Sender is not wearer of the hat");
        IDAO.Action [] idaoAction = hasRemainingBudget(_myActions);
        dao().execute({_callId: 0x0, _actions: idaoAction, _allowFailureMap: 0});
    }
}
